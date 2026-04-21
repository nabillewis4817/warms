from django.conf import settings
from django.db import models
from django.utils import timezone

from patients.models import Patient


class RendezVous(models.Model):
    """
    Rendez-vous du cabinet dentaire.

    - programmé / confirmé / effectué / annulé / absent / reporté
    - lié à un patient
    - affecté à un praticien (chirurgien-dentiste) ou à une infirmière si besoin
    """

    class Statut(models.TextChoices):
        PROGRAMME = "programme", "Programmé"
        CONFIRME = "confirme", "Confirmé"
        REPORTE = "reporte", "Reporté"
        ANNULE = "annule", "Annulé"
        ABSENT = "absent", "Absent"
        EFFECTUE = "effectue", "Effectué"

    patient = models.ForeignKey(Patient, on_delete=models.PROTECT, related_name="rendez_vous")

    # Personnel affecté (optionnel au début)
    praticien = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="rendez_vous_praticien",
        help_text="Chirurgien-dentiste (ou praticien) en charge.",
    )
    infirmiere = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="rendez_vous_infirmiere",
        help_text="Infirmière associée (ex: préparation, suivi).",
    )

    debut = models.DateTimeField()
    fin = models.DateTimeField()

    motif = models.CharField(max_length=255, blank=True)
    notes = models.TextField(blank=True)

    statut = models.CharField(max_length=16, choices=Statut.choices, default=Statut.PROGRAMME)

    motif_absence = models.CharField(max_length=255, blank=True)
    raison_annulation = models.CharField(max_length=255, blank=True)

    cree_par = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="rendez_vous_crees",
    )

    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-debut"]
        indexes = [
            models.Index(fields=["debut"]),
            models.Index(fields=["statut"]),
        ]

    def clean(self):
        # Validation simple: fin après debut
        if self.fin and self.debut and self.fin <= self.debut:
            from django.core.exceptions import ValidationError

            raise ValidationError({"fin": "La fin doit être après le début."})

    @property
    def est_passe(self) -> bool:
        return self.fin < timezone.now()

    def __str__(self) -> str:
        return f"RDV {self.patient} — {self.debut:%d/%m/%Y %H:%M}"


#EbaJioloLewis
