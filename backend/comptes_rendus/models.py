from django.conf import settings
from django.db import models

from patients.models import Patient


class CompteRendu(models.Model):
    class TypeAction(models.TextChoices):
        CONSULTATION    = "consultation",     "Consultation"
        RENDEZ_VOUS     = "rendez_vous",      "Rendez-vous"
        OPERATION       = "operation",        "Opération"
        SCHEMA_DENTAIRE = "schema_dentaire",  "Schéma dentaire"
        AUTRE           = "autre",            "Autre"

    patient    = models.ForeignKey(Patient, on_delete=models.PROTECT, related_name="comptes_rendus")
    praticien  = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name="comptes_rendus_rediges",
    )

    type_action   = models.CharField(max_length=20, choices=TypeAction.choices, default=TypeAction.CONSULTATION)
    reference_id  = models.IntegerField(null=True, blank=True, help_text="ID de la consultation/RDV source")
    titre         = models.CharField(max_length=255)
    contenu       = models.TextField()
    contenu_ia_brut = models.TextField(blank=True, help_text="Texte IA original avant édition manuelle")
    genere_par_ia = models.BooleanField(default=False)

    cree_le    = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-cree_le"]
        indexes  = [models.Index(fields=["patient", "type_action"])]

    def __str__(self):
        return f"{self.get_type_action_display()} — {self.patient} ({self.cree_le:%d/%m/%Y})"


#EbaJioloLewis
