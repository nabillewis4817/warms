from django.contrib.auth.models import AbstractUser
from django.db import models


class Utilisateur(AbstractUser):
    """
    Utilisateur unique de la plateforme Warm's.

    On centralise ici le rôle pour simplifier:
    - les permissions backend (DRF)
    - les guards côté Angular
    - l'UX côté mobile (menus/écrans selon rôle)
    """

    class Role(models.TextChoices):
        CHIRURGIEN_DENTISTE = "chirurgien_dentiste", "Chirurgien-dentiste"
        SECRETAIRE = "secretaire", "Secrétaire"
        INFIRMIERE = "infirmiere", "Infirmière"
        PATIENT = "patient", "Patient"

    role = models.CharField(
        max_length=32,
        choices=Role.choices,
        default=Role.PATIENT,
        help_text="Rôle fonctionnel pour les accès et l'expérience utilisateur.",
    )

    telephone = models.CharField(
        max_length=32,
        blank=True,
        help_text="Numéro de téléphone (utile pour SMS / WhatsApp / contact).",
    )
    photo_profil = models.ImageField(
        upload_to="profils/photos/",
        null=True,
        blank=True,
        help_text="Photo de profil utilisateur.",
    )
    langue_interface = models.CharField(
        max_length=8,
        default="fr",
        help_text="Langue préférée de l'interface (fr/en).",
    )
    mode_sombre = models.BooleanField(default=False)
    preferences_notifications = models.JSONField(
        default=dict,
        blank=True,
        help_text="Ex: {'email': true, 'sms': false, 'push': true, 'rappels_auto': true}",
    )

    def __str__(self) -> str:
        base = self.get_full_name() or self.username
        return f"{base} ({self.get_role_display()})"


#EbaJioloLewis
