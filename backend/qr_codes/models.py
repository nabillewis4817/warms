import secrets

from django.db import models

from patients.models import DossierPatient


class CarnetQRCode(models.Model):
    """
    QR code d'authentification d'un carnet/dossier.

    Principe:
    - on encode dans le QR une valeur de type token (non prédictible)
    - l'appli mobile scanne -> envoie token -> on récupère le dossier associé
    """

    dossier = models.OneToOneField(
        DossierPatient,
        on_delete=models.CASCADE,
        related_name="qr",
    )

    token = models.CharField(max_length=64, unique=True, db_index=True)
    actif = models.BooleanField(default=True)
    cree_le = models.DateTimeField(auto_now_add=True)

    @staticmethod
    def generer_token() -> str:
        # ~43 chars base64url, suffisant et pratique pour QR
        return secrets.token_urlsafe(32)

    def save(self, *args, **kwargs):
        if not self.token:
            self.token = self.generer_token()
        super().save(*args, **kwargs)

    def __str__(self) -> str:
        return f"QR {self.dossier.numero_dossier}"
