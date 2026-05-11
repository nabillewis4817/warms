from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from journaux.utils import journaliser
from messagerie.models import Conversation, NotificationInterne, ParticipantConversation
from personnel.models import Utilisateur
from personnel.permissions import EstPersonnelCabinet
from qr_codes.models import CarnetQRCode

from .models import AvisPatient, DossierPatient, PageCarnet, Patient, PieceJointeDossier
from .serializers import (
    AvisPatientSerializer,
    DossierPatientCreateSerializer,
    DossierPatientSerializer,
    PageCarnetSerializer,
    PatientSerializer,
    PieceJointeDossierSerializer,
)


class PatientViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    queryset = Patient.objects.all()
    serializer_class = PatientSerializer

    def get_permissions(self):
        """
        Définir les permissions en fonction de l'action
        """
        if self.action == 'destroy':
            self.permission_classes = [IsAuthenticated, EstPersonnelCabinet]
        elif self.action in ['create', 'update', 'partial_update']:
            self.permission_classes = [IsAuthenticated, EstPersonnelCabinet]
        elif self.action == 'me':
            # L'action 'me' est accessible par tout utilisateur authentifié (patients)
            self.permission_classes = [IsAuthenticated]
        return super().get_permissions()

    def create(self, request, *args, **kwargs):
        data = request.data
        prenom = (data.get("prenom") or "").strip()
        nom = (data.get("nom") or "").strip()
        telephone = (data.get("telephone") or "").strip()
        email = (data.get("email") or "").strip()

        doublons = Patient.objects.filter(prenom__iexact=prenom, nom__iexact=nom, actif=True)
        if telephone:
            doublons = doublons.filter(telephone__iexact=telephone)
        elif email:
            doublons = doublons.filter(email__iexact=email)
        # Si nom/prénom existent déjà en actif sans précision, on bloque aussi pour éviter les doublons.
        if doublons.exists() or (
            not telephone and not email and Patient.objects.filter(prenom__iexact=prenom, nom__iexact=nom, actif=True).exists()
        ):
            return Response(
                {"detail": "Un patient actif avec ces informations existe déjà."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        patient = serializer.save()
        self._creer_dossier_qr(patient)

        username = (request.data.get("username_patient") or "").strip()
        password = (request.data.get("password_patient") or "").strip()
        
        # Rendre username et password obligatoires
        if not username or not password:
            return Response(
                {"detail": "Le nom d'utilisateur et le mot de passe du patient sont obligatoires."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not Utilisateur.objects.filter(username=username).exists():
            compte_patient = Utilisateur.objects.create_user(
                username=username,
                password=password,
                role=Utilisateur.Role.PATIENT,
                first_name=patient.prenom,
                last_name=patient.nom,
                email=patient.email,
                telephone=patient.telephone,
            )
            patient.user = compte_patient
            patient.save(update_fields=["user"])
        payload = self.get_serializer(patient).data
        payload["identifiants_patient"] = {"username": username, "password": password}
        return Response(payload, status=status.HTTP_201_CREATED)

    def _creer_dossier_qr(self, patient):
        # Création automatique du dossier + QR unique à la création patient.
        numero_dossier = f"WARMS-{patient.id:06d}"
        dossier = DossierPatient.objects.create(patient=patient, numero_dossier=numero_dossier)
        CarnetQRCode.objects.create(dossier=dossier)
        journaliser(
            acteur=self.request.user,
            action="patient.created_with_qr",
            objet_type="Patient",
            objet_id=patient.id,
            message=f"Patient créé avec dossier {numero_dossier} et QR auto-généré.",
        )
        self._creer_conversation_patient(patient)

    def _creer_conversation_patient(self, patient):
        participants = []
        if patient.user_id:
            participants.append(patient.user_id)
        if patient.infirmiere_referente_id:
            participants.append(patient.infirmiere_referente_id)
        chirurgien = Utilisateur.objects.filter(
            role=Utilisateur.Role.CHIRURGIEN_DENTISTE, is_active=True
        ).first()
        if chirurgien:
            participants.append(chirurgien.id)
        participants = list({p for p in participants if p})
        if not participants:
            return
        conversation = Conversation.objects.create(
            titre=f"Suivi patient {patient.prenom} {patient.nom}",
            type_conversation=Conversation.TypeConversation.PATIENT,
            patient=patient,
            cree_par=self.request.user,
        )
        for uid in participants:
            ParticipantConversation.objects.get_or_create(
                conversation=conversation, utilisateur_id=uid
            )
            if uid != getattr(self.request.user, "id", None):
                NotificationInterne.objects.create(
                    destinataire_id=uid,
                    titre="Conversation patient créée",
                    contenu=f"Conversation de suivi ouverte pour {patient.prenom} {patient.nom}.",
                    niveau=NotificationInterne.Niveau.MESSAGE,
                )

    @action(detail=True, methods=["post"], permission_classes=[EstPersonnelCabinet])
    def archiver(self, request, pk=None):
        patient = self.get_object()
        patient.actif = False
        patient.save(update_fields=["actif", "modifie_le"])
        journaliser(
            acteur=request.user,
            action="patient.archived",
            objet_type="Patient",
            objet_id=patient.id,
            message=f"Archivage du patient {patient.prenom} {patient.nom}.",
        )
        return Response({"id": patient.id, "actif": patient.actif})

    @action(detail=True, methods=["post"], permission_classes=[EstPersonnelCabinet])
    def desarchiver(self, request, pk=None):
        patient = self.get_object()
        patient.actif = True
        patient.save(update_fields=["actif", "modifie_le"])
        journaliser(
            acteur=request.user,
            action="patient.unarchived",
            objet_type="Patient",
            objet_id=patient.id,
            message=f"Désarchivage du patient {patient.prenom} {patient.nom}.",
        )
        return Response({"id": patient.id, "actif": patient.actif})

    def destroy(self, request, pk=None):
        """
        Supprime définitivement un patient avec ses données associées.
        """
        print(f"Tentative de suppression patient {pk} par utilisateur {request.user}")
        print(f"Utilisateur authentifié: {request.user.is_authenticated}")
        print(f"Rôle utilisateur: {getattr(request.user, 'role', 'Non défini')}")
        
        try:
            patient = self.get_object()
            print(f"Patient trouvé: {patient.prenom} {patient.nom}")
        except Exception as e:
            print(f"Erreur lors de la récupération du patient: {e}")
            return Response(
                {"detail": f"Patient introuvable: {str(e)}"}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Journaliser la suppression
        journaliser(
            acteur=request.user,
            action="patient.deleted",
            objet_type="Patient",
            objet_id=patient.id,
            message=f"Suppression définitive du patient {patient.prenom} {patient.nom}.",
        )
        
        try:
            # Supprimer le patient (cascade automatique grâce aux related_name)
            patient.delete()
            print(f"Patient {patient.id} supprimé avec succès")
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Exception as e:
            print(f"Erreur lors de la suppression du patient: {e}")
            return Response(
                {"detail": f"Erreur lors de la suppression: {str(e)}"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @action(detail=True, methods=["post"], permission_classes=[EstPersonnelCabinet])
    def affecter_infirmiere(self, request, pk=None):
        """
        Affecte une infirmière référente au patient.
        Payload:
        - infirmiere_id: int
        """
        patient = self.get_object()
        infirmiere_id = request.data.get("infirmiere_id")
        infirmiere = Utilisateur.objects.filter(
            id=infirmiere_id, role=Utilisateur.Role.INFIRMIERE, is_active=True
        ).first()
        if not infirmiere:
            return Response({"detail": "Infirmière introuvable."}, status=status.HTTP_404_NOT_FOUND)

        patient.infirmiere_referente = infirmiere
        patient.save(update_fields=["infirmiere_referente", "modifie_le"])
        journaliser(
            acteur=request.user,
            action="patient.assigned_nurse",
            objet_type="Patient",
            objet_id=patient.id,
            message=f"Infirmière référente affectée: {infirmiere.username}.",
            metadata={"infirmiere_id": infirmiere.id},
        )
        return Response(self.get_serializer(patient).data)

    @action(detail=False, methods=["get"], url_path="me")
    def me(self, request):
        try:
            # Vérifier l'authentification
            if not request.user.is_authenticated:
                return Response({"detail": "Utilisateur non authentifié."}, status=401)
            
            # Vérifier si l'utilisateur est un patient ou superutilisateur
            user_role = getattr(request.user, 'role', None)
            if not request.user.is_superuser and (not user_role or user_role.lower() not in ['patient', 'PATIENT']):
                return Response({"detail": "L'utilisateur n'est pas un patient."}, status=403)
            
            # Rechercher le patient lié à cet utilisateur
            patient = Patient.objects.filter(user=request.user).first()
            if not patient:
                return Response({
                    "detail": "Profil patient introuvable.",
                    "user_id": request.user.id,
                    "username": request.user.username,
                    "debug_role": user_role
                }, status=404)
            
            # Retourner les données du patient
            serializer = self.get_serializer(patient)
            return Response(serializer.data)
            
        except Exception as e:
            return Response({
                "detail": "Erreur lors de la récupération du profil patient.",
                "error": str(e),
                "debug_info": {
                    "user_id": getattr(request.user, 'id', None),
                    "username": getattr(request.user, 'username', None),
                    "is_authenticated": getattr(request.user, 'is_authenticated', False),
                    "role": getattr(request.user, 'role', None)
                }
            }, status=500)


class AvisPatientViewSet(viewsets.ModelViewSet):
    queryset = AvisPatient.objects.select_related("patient", "auteur").all()
    serializer_class = AvisPatientSerializer

    def perform_create(self, serializer):
        serializer.save(auteur=self.request.user)


class DossierPatientViewSet(viewsets.ModelViewSet):
    queryset = DossierPatient.objects.select_related("patient").all()

    def get_serializer_class(self):
        if self.action == "create":
            return DossierPatientCreateSerializer
        return DossierPatientSerializer


class PageCarnetViewSet(viewsets.ModelViewSet):
    queryset = PageCarnet.objects.select_related("dossier").all()
    serializer_class = PageCarnetSerializer


class PieceJointeDossierViewSet(
    mixins.CreateModelMixin, mixins.DestroyModelMixin, mixins.ListModelMixin, viewsets.GenericViewSet
):
    queryset = PieceJointeDossier.objects.select_related("dossier").all()
    serializer_class = PieceJointeDossierSerializer
    parser_classes = [MultiPartParser, FormParser]

    def create(self, request, *args, **kwargs):
        """
        Upload multipart:
        - dossier: UUID
        - fichier: file
        - libelle: optional
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        instance = serializer.save()
        return Response(
            self.get_serializer(instance).data,
            status=status.HTTP_201_CREATED,
        )


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def supprimer_patient_ameliore(request, pk):
    """
    Endpoint de suppression patient amélioré avec vérifications détaillées
    """
    try:
        # Vérifier l'authentification
        if not request.user.is_authenticated:
            return Response(
                {'detail': 'Authentication requise'}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Vérifier les permissions
        permission = EstPersonnelCabinet()
        if not permission.has_permission(request, None):
            return Response(
                {
                    'detail': 'Permission refusée', 
                    'user_role': getattr(request.user, 'role', 'None'),
                    'is_superuser': request.user.is_superuser,
                    'required_roles': ['CHIRURGIEN_DENTISTE', 'SECRETAIRE', 'INFIRMIERE']
                }, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Récupérer le patient
        try:
            patient = Patient.objects.get(pk=pk)
        except Patient.DoesNotExist:
            return Response(
                {'detail': 'Patient non trouvé'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Journaliser la suppression
        journaliser(
            acteur=request.user,
            action="patient.suppression",
            objet_type="Patient",
            objet_id=patient.id,
            message=f"Suppression du patient {patient.prenom} {patient.nom}",
            metadata={
                'patient_nom': f"{patient.prenom} {patient.nom}",
                'patient_email': patient.email,
                'supprime_par': request.user.username
            }
        )
        
        # Supprimer le patient
        patient.delete()
        
        return Response(
            {
                'detail': 'Patient supprimé avec succès',
                'patient_nom': f"{patient.prenom} {patient.nom}",
                'supprime_par': request.user.username
            }, 
            status=status.HTTP_200_OK
        )
        
    except Exception as e:
        print(f"Erreur suppression patient: {e}")
        return Response(
            {'detail': f'Erreur lors de la suppression: {str(e)}'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
