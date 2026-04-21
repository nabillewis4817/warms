from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from journaux.utils import journaliser
from personnel.models import Utilisateur
from personnel.permissions import EstPersonnelCabinet

from .models import DossierPatient, PageCarnet, Patient, PieceJointeDossier
from .serializers import (
    DossierPatientCreateSerializer,
    DossierPatientSerializer,
    PageCarnetSerializer,
    PatientSerializer,
    PieceJointeDossierSerializer,
)


class PatientViewSet(viewsets.ModelViewSet):
    queryset = Patient.objects.all()
    serializer_class = PatientSerializer

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
