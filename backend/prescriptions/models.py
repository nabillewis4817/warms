from django.conf import settings
from django.db import models

from consultations.models import Consultation
from patients.models import DossierPatient, Patient


class Prescription(models.Model):
    """
    Prescription numérique liée à une consultation.

    L'ordonnance PDF sera générée depuis ces données.
    """

    patient = models.ForeignKey(Patient, on_delete=models.PROTECT, related_name="prescriptions")
    dossier = models.ForeignKey(DossierPatient, on_delete=models.PROTECT, related_name="prescriptions")
    consultation = models.ForeignKey(
        Consultation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="prescriptions",
        help_text="Consultation à l'origine de la prescription (recommandé).",
    )

    praticien = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="prescriptions_praticien",
    )

    titre = models.CharField(
        max_length=255,
        blank=True,
        help_text="Ex: Ordonnance post-op, Ordonnance douleur, etc.",
    )
    note_praticien = models.TextField(blank=True)
    conseils = models.TextField(
        blank=True,
        help_text="Conseils donnés au patient (hygiène, alimentation, soins post-traitement...).",
    )
    recommandations = models.TextField(
        blank=True,
        help_text="Recommandations complémentaires (suivi, examens, rendez-vous de contrôle...).",
    )

    class Statut(models.TextChoices):
        ACTIVE = "active", "Active"
        TERMINEE = "terminee", "Terminée"
        ANNULEE = "annulee", "Annulée"

    statut = models.CharField(max_length=20, choices=Statut.choices, default=Statut.ACTIVE)

    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-cree_le"]
        indexes = [
            models.Index(fields=["cree_le"]),
        ]

    def __str__(self) -> str:
        return f"Prescription {self.patient} — {self.cree_le:%d/%m/%Y}"


class LignePrescription(models.Model):
    """
    Une ligne de médicament / consigne sur l'ordonnance.

    On reste volontairement simple:
    - médicament
    - posologie
    - durée
    - remarques
    """

    prescription = models.ForeignKey(
        Prescription, on_delete=models.CASCADE, related_name="lignes"
    )
    medicament = models.CharField(max_length=255)
    posologie = models.CharField(max_length=255, blank=True)
    duree = models.CharField(max_length=255, blank=True)
    remarques = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["id"]

    def __str__(self) -> str:
        return self.medicament


#EbaJioloLewis
