from rest_framework import mixins, status, viewsets
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from .models import ActeRealise, Consultation, PhotoClinique, SchemaDentaire
from .serializers import (
    ActeRealiseSerializer,
    ConsultationSerializer,
    PhotoCliniqueSerializer,
    SchemaDentaireSerializer,
)


class ConsultationViewSet(viewsets.ModelViewSet):
    queryset = Consultation.objects.select_related(
        "patient", "dossier", "rendez_vous", "praticien"
    ).all()
    serializer_class = ConsultationSerializer


class ActeRealiseViewSet(viewsets.ModelViewSet):
    queryset = ActeRealise.objects.select_related("consultation").all()
    serializer_class = ActeRealiseSerializer


class SchemaDentaireViewSet(
    mixins.CreateModelMixin, mixins.UpdateModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet
):
    queryset = SchemaDentaire.objects.select_related("consultation").all()
    serializer_class = SchemaDentaireSerializer


class PhotoCliniqueViewSet(
    mixins.CreateModelMixin, mixins.DestroyModelMixin, mixins.ListModelMixin, viewsets.GenericViewSet
):
    queryset = PhotoClinique.objects.select_related("consultation").all()
    serializer_class = PhotoCliniqueSerializer
    parser_classes = [MultiPartParser, FormParser]

    def create(self, request, *args, **kwargs):
        """
        Upload multipart:
        - consultation: id
        - fichier: image
        - type_photo: pre_op|post_op|autre
        - commentaire: optionnel
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        instance = serializer.save()
        return Response(self.get_serializer(instance).data, status=status.HTTP_201_CREATED)


#EbaJioloLewis
