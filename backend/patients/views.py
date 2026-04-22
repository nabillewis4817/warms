from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, MultiPartParser
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
    queryset = Patient.objects.all()
    serializer_class = PatientSerializer

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
        if not username:
            username = f"patient{patient.id:06d}"
        if not password:
            password = Utilisateur.objects.make_random_password(
                length=8, allowed_chars="abcdefghjkmnpqrstuvwxyz23456789"
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

    @action(detail=True, methods=["post"])
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
        patient = Patient.objects.filter(user=request.user).first()
        if not patient:
            return Response({"detail": "Profil patient introuvable."}, status=404)
        return Response(self.get_serializer(patient).data)


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
