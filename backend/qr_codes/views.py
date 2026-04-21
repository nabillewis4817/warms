from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import CarnetQRCode
from .serializers import CarnetQRCodeSerializer, VerifierCarnetQRSerializer


class CarnetQRCodeViewSet(viewsets.ModelViewSet):
    queryset = CarnetQRCode.objects.select_related("dossier", "dossier__patient").all()
    serializer_class = CarnetQRCodeSerializer

    @action(detail=False, methods=["post"], permission_classes=[AllowAny])
    def verifier(self, request):
        """
        Endpoint public (scan QR) : retourne le dossier lié au token.
        Le front pourra ensuite appliquer ses propres règles (afficher un écran,
        demander auth, etc.).
        """
        serializer = VerifierCarnetQRSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = serializer.validated_data["token"]

        try:
            qr = CarnetQRCode.objects.select_related("dossier", "dossier__patient").get(
                token=token, actif=True
            )
        except CarnetQRCode.DoesNotExist:
            return Response({"detail": "QR invalide ou expiré."}, status=status.HTTP_404_NOT_FOUND)

        dossier = qr.dossier
        patient = dossier.patient
        return Response(
            {
                "dossier": {
                    "id": str(dossier.id),
                    "numero_dossier": dossier.numero_dossier,
                },
                "patient": {
                    "id": patient.id,
                    "prenom": patient.prenom,
                    "nom": patient.nom,
                },
            }
        )
