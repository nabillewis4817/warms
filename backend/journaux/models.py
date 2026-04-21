from django.conf import settings
from django.db import models


class LogActivite(models.Model):
    """
    Journalisation simple des actions importantes dans le cabinet.

    Objectif:
    - pouvoir auditer "qui a fait quoi"
    - permettre un écran 'activité' côté admin
    - faciliter le support en cas d'incident
    """

    acteur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="logs_activite",
    )

    action = models.CharField(max_length=64, help_text="Ex: user.created, patient.assigned_nurse")
    objet_type = models.CharField(max_length=64, blank=True, help_text="Ex: Utilisateur, Patient")
    objet_id = models.CharField(max_length=64, blank=True, help_text="Id de l'objet concerné (string).")

    message = models.CharField(max_length=255, blank=True)
    metadata = models.JSONField(default=dict, blank=True)

    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-cree_le"]
        indexes = [
            models.Index(fields=["action"]),
            models.Index(fields=["cree_le"]),
        ]

    def __str__(self) -> str:
        who = str(self.acteur) if self.acteur else "Système"
        return f"{self.action} — {who} — {self.cree_le:%d/%m/%Y %H:%M}"


#EbaJioloLewis
