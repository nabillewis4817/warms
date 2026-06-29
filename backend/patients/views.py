from django.core.files.base import ContentFile
from django.db import transaction
from django.utils import timezone
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
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

ACTIONS_CORBEILLE = ("corbeille", "restaurer_corbeille", "supprimer_definitivement")


class PatientViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = PatientSerializer

    def get_queryset(self):
        if self.action in ACTIONS_CORBEILLE:
            return Patient.objects.filter(supprime_le__isnull=False).order_by("-supprime_le")
        return Patient.objects.filter(supprime_le__isnull=True)

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

        # La photo est obligatoire à la création : elle sert d'identification
        # visuelle lors de la connexion mobile ("Est-ce bien vous ?").
        if not request.FILES.get("photo"):
            return Response(
                {"detail": "Une photo du patient est obligatoire à la création."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        patient = serializer.save()
        self._creer_dossier_qr(patient, allergies=(request.data.get("allergies") or "").strip())

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
            # La photo du patient sert aussi de photo de profil de son compte
            # de connexion : c'est elle qui s'affiche à l'écran "Est-ce bien
            # vous ?" lors de la connexion mobile (lue depuis Utilisateur,
            # pas depuis Patient).
            if patient.photo:
                patient.photo.open("rb")
                compte_patient.photo_profil.save(
                    patient.photo.name.split("/")[-1],
                    ContentFile(patient.photo.read()),
                    save=False,
                )
                patient.photo.close()
            patient.user = compte_patient
            patient.save(update_fields=["user"])
            compte_patient.save(update_fields=["photo_profil"])
        payload = self.get_serializer(patient).data
        payload["identifiants_patient"] = {"username": username, "password": password}
        return Response(payload, status=status.HTTP_201_CREATED)

    def _creer_dossier_qr(self, patient, allergies=""):
        # Création automatique du dossier + QR unique à la création patient.
        numero_dossier = f"WARMS-{patient.id:06d}"
        dossier = DossierPatient.objects.create(
            patient=patient, numero_dossier=numero_dossier, allergies=allergies
        )
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
        Suppression douce par défaut (déplacement vers la corbeille).
        Pour une suppression définitive, utiliser l'action `supprimer-definitivement`.
        """
        return self.mettre_corbeille(request, pk=pk)

    @action(detail=False, methods=["get"], permission_classes=[EstPersonnelCabinet])
    def corbeille(self, request):
        """
        Liste des patients mis à la corbeille (suppression douce).
        """
        serializer = self.get_serializer(self.get_queryset(), many=True)
        return Response(serializer.data)

    @action(detail=True, methods=["post"], url_path="corbeille", permission_classes=[EstPersonnelCabinet])
    def mettre_corbeille(self, request, pk=None):
        """
        Déplace un patient vers la corbeille (suppression douce, réversible).
        """
        patient = self.get_object()
        patient.supprime_le = timezone.now()
        patient.save(update_fields=["supprime_le", "modifie_le"])
        journaliser(
            acteur=request.user,
            action="patient.trashed",
            objet_type="Patient",
            objet_id=patient.id,
            message=f"Patient {patient.prenom} {patient.nom} déplacé vers la corbeille.",
        )
        return Response(
            {"id": patient.id, "detail": f"{patient.prenom} {patient.nom} déplacé vers la corbeille."}
        )

    @action(detail=True, methods=["post"], url_path="restaurer-corbeille", permission_classes=[EstPersonnelCabinet])
    def restaurer_corbeille(self, request, pk=None):
        """
        Restaure un patient depuis la corbeille.
        """
        patient = self.get_object()
        patient.supprime_le = None
        patient.save(update_fields=["supprime_le", "modifie_le"])
        journaliser(
            acteur=request.user,
            action="patient.restored",
            objet_type="Patient",
            objet_id=patient.id,
            message=f"Patient {patient.prenom} {patient.nom} restauré depuis la corbeille.",
        )
        return Response(self.get_serializer(patient).data)

    @action(
        detail=True,
        methods=["delete"],
        url_path="supprimer-definitivement",
        permission_classes=[EstPersonnelCabinet],
    )
    def supprimer_definitivement(self, request, pk=None):
        """
        Supprime définitivement un patient (depuis la corbeille) ainsi que
        toutes ses données cliniques liées (consultations, dossier, pièces jointes).
        Action irréversible.
        """
        from consultations.models import Consultation

        patient = self.get_object()
        nom_complet = f"{patient.prenom} {patient.nom}"
        patient_id = patient.id

        with transaction.atomic():
            Consultation.objects.filter(patient=patient).delete()
            try:
                patient.dossier.delete()
            except DossierPatient.DoesNotExist:
                pass
            patient.delete()

        journaliser(
            acteur=request.user,
            action="patient.deleted_permanently",
            objet_type="Patient",
            objet_id=patient_id,
            message=f"Suppression définitive du patient {nom_complet} (corbeille).",
        )
        return Response(
            {"detail": f"{nom_complet} supprimé définitivement.", "id": patient_id},
            status=status.HTTP_200_OK,
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
    permission_classes = [IsAuthenticated]
    queryset = AvisPatient.objects.select_related("patient", "auteur").all()
    serializer_class = AvisPatientSerializer

    def perform_create(self, serializer):
        serializer.save(auteur=self.request.user)

    @action(detail=False, methods=["get"])
    def statistiques(self, request):
        from datetime import timedelta

        from django.db.models import Avg
        from django.utils import timezone

        queryset = self.get_queryset()
        recents_depuis = timezone.now() - timedelta(days=30)

        par_note = {
            str(note): queryset.filter(note=note).count() for note in range(1, 6)
        }

        return Response(
            {
                "total_avis": queryset.count(),
                "note_moyenne": queryset.aggregate(moyenne=Avg("note"))["moyenne"] or 0,
                "avis_recents": queryset.filter(cree_le__gte=recents_depuis).count(),
                "avec_reponse": 0,
                "par_type": {},
                "par_note": par_note,
                "par_statut": {},
            }
        )


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


