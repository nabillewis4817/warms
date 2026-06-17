import secrets

from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone


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
    est_valide_par_chirurgien = models.BooleanField(
        default=True,
        help_text="Pour le personnel créé par une secrétaire, validation du chirurgien requise.",
    )
    valide_par = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="personnels_valides",
    )
    valide_le = models.DateTimeField(null=True, blank=True)
    derniere_activite = models.DateTimeField(
        null=True, blank=True, help_text="Dernière requête authentifiée (présence en ligne)."
    )

    SEUIL_EN_LIGNE = timezone.timedelta(minutes=2)

    def __str__(self) -> str:
        base = self.get_full_name() or self.username
        return f"{base} ({self.get_role_display()})"

    @property
    def est_en_ligne(self) -> bool:
        if not self.derniere_activite:
            return False
        return timezone.now() - self.derniere_activite < self.SEUIL_EN_LIGNE

    def valider_par_chirurgien(self, chirurgien):
        self.est_valide_par_chirurgien = True
        self.is_active = True
        self.valide_par = chirurgien
        self.valide_le = timezone.now()
        self.save(
            update_fields=[
                "est_valide_par_chirurgien",
                "is_active",
                "valide_par",
                "valide_le",
            ]
        )


class PasswordResetToken(models.Model):
    utilisateur = models.ForeignKey(
        Utilisateur, on_delete=models.CASCADE, related_name="password_reset_tokens"
    )
    token = models.CharField(max_length=128, unique=True, db_index=True)
    utilise = models.BooleanField(default=False)
    cree_le = models.DateTimeField(auto_now_add=True)

    @staticmethod
    def generate() -> str:
        return secrets.token_urlsafe(48)


#EbaJioloLewis
