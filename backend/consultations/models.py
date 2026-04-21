from django.conf import settings
from django.db import models

from patients.models import DossierPatient, Patient
from rendez_vous.models import RendezVous


class Consultation(models.Model):
    """
    Consultation / séance clinique.

    Objectif: garder une trace "séance par séance":
    - observations cliniques
    - diagnostic
    - notes du chirurgien-dentiste
    - actes réalisés
    - schéma dentaire (versionné par consultation)
    - photos pré/post-op
    """

    patient = models.ForeignKey(Patient, on_delete=models.PROTECT, related_name="consultations")
    dossier = models.ForeignKey(DossierPatient, on_delete=models.PROTECT, related_name="consultations")

    rendez_vous = models.OneToOneField(
        RendezVous,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="consultation",
        help_text="Rendez-vous associé (si la consultation provient du planning).",
    )

    praticien = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="consultations_praticien",
    )

    date = models.DateTimeField()
    motif = models.CharField(max_length=255, blank=True)

    observations = models.TextField(blank=True)
    diagnostic = models.TextField(blank=True)
    notes = models.TextField(blank=True)

    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-date"]
        indexes = [
            models.Index(fields=["date"]),
        ]

    def __str__(self) -> str:
        return f"Consultation {self.patient} — {self.date:%d/%m/%Y %H:%M}"


class ActeRealise(models.Model):
    """
    Acte/soin effectué pendant la consultation (ex: détartrage, extraction...).
    """

    consultation = models.ForeignKey(Consultation, on_delete=models.CASCADE, related_name="actes")
    libelle = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    dent = models.CharField(
        max_length=16,
        blank=True,
        help_text="Optionnel: dent concernée (notation à préciser plus tard).",
    )
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["id"]

    def __str__(self) -> str:
        return self.libelle


class SchemaDentaire(models.Model):
    """
    Schéma dentaire associé à une consultation.

    Format JSON libre au départ (côté front on stockera l'état du diagramme).
    """

    consultation = models.OneToOneField(
        Consultation, on_delete=models.CASCADE, related_name="schema_dentaire"
    )
    donnees = models.JSONField(default=dict, blank=True)
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f"Schéma — {self.consultation}"


class PhotoClinique(models.Model):
    """
    Photo clinique pré/post opératoire ou image de contrôle.
    """

    class TypePhoto(models.TextChoices):
        PRE_OP = "pre_op", "Pré-opératoire"
        POST_OP = "post_op", "Post-opératoire"
        AUTRE = "autre", "Autre"

    consultation = models.ForeignKey(
        Consultation, on_delete=models.CASCADE, related_name="photos"
    )
    fichier = models.ImageField(upload_to="consultations/photos/")
    type_photo = models.CharField(max_length=16, choices=TypePhoto.choices, default=TypePhoto.AUTRE)
    commentaire = models.CharField(max_length=255, blank=True)
    cree_le = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"Photo {self.get_type_photo_display()} — {self.consultation}"


#EbaJioloLewis
