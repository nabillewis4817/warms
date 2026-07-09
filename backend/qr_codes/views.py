from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
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

    @action(detail=False, methods=["get"], permission_classes=[IsAuthenticated])
    def mon_qr(self, request):
        """Retourne (ou crée) le QR token du patient connecté (rôle patient uniquement)."""
        import uuid
        from personnel.models import Utilisateur
        from patients.models import Patient, DossierPatient

        user = request.user
        if getattr(user, 'role', None) != Utilisateur.Role.PATIENT:
            return Response({"detail": "Réservé aux patients."}, status=status.HTTP_403_FORBIDDEN)

        try:
            patient = Patient.objects.get(user=user)
        except Patient.DoesNotExist:
            # Fallback : chercher par email et auto-lier si le profil n'a encore aucun compte
            patient = None
            if user.email:
                try:
                    candidate = Patient.objects.get(email__iexact=user.email)
                    if not candidate.user_id:
                        # Aucun compte lié → on relie automatiquement
                        candidate.user = user
                        candidate.save(update_fields=["user"])
                        patient = candidate
                    elif candidate.user_id == user.id:
                        # Déjà lié au même compte (cohérence)
                        patient = candidate
                    # Si lié à un autre compte → on refuse (sécurité)
                except Patient.DoesNotExist:
                    pass
            if patient is None:
                return Response({"detail": "Profil patient introuvable."}, status=status.HTTP_404_NOT_FOUND)

        # Auto-créer le DossierPatient s'il n'existe pas encore
        try:
            dossier = patient.dossier
        except Exception:
            dossier = DossierPatient.objects.create(
                patient=patient,
                numero_dossier=f"DOS-{patient.id}-{uuid.uuid4().hex[:6].upper()}",
            )

        # Auto-créer le QR code s'il n'existe pas encore
        qr, _ = CarnetQRCode.objects.get_or_create(dossier=dossier)
        if not qr.actif:
            qr.actif = True
            qr.save(update_fields=["actif"])

        return Response({
            "token": qr.token,
            "patient": {
                "id": patient.id,
                "prenom": patient.prenom,
                "nom": patient.nom,
            },
            "dossier": {
                "id": str(dossier.id),
                "numero_dossier": dossier.numero_dossier,
            }
        })
