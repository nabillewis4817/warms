from django.conf import settings
from django.db import models

from patients.models import Patient


class Conversation(models.Model):
    """
    Conversation de messagerie:
    - interne (personnel <-> personnel)
    - patient (personnel <-> patient)
    """

    class TypeConversation(models.TextChoices):
        INTERNE = "interne", "Interne"
        PATIENT = "patient", "Patient"

    titre = models.CharField(max_length=255, blank=True)
    type_conversation = models.CharField(
        max_length=16, choices=TypeConversation.choices, default=TypeConversation.INTERNE
    )
    patient = models.ForeignKey(
        Patient,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="conversations",
        help_text="Renseigné pour les conversations liées à un patient.",
    )
    cree_par = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True
    )
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    participants = models.ManyToManyField(
        settings.AUTH_USER_MODEL, related_name="conversations", through="ParticipantConversation"
    )

    class Meta:
        ordering = ["-modifie_le"]

    def __str__(self) -> str:
        return self.titre or f"Conversation #{self.id}"


class ParticipantConversation(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE)
    utilisateur = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    est_admin = models.BooleanField(default=False)
    a_mute = models.BooleanField(default=False)
    rejoint_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [("conversation", "utilisateur")]


class Message(models.Model):
    conversation = models.ForeignKey(
        Conversation, on_delete=models.CASCADE, related_name="messages"
    )
    auteur = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    contenu = models.TextField()
    lu = models.BooleanField(default=False)
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["cree_le"]


class NotificationInterne(models.Model):
    """
    Notification applicative de base (push/email branchés ensuite).
    """

    destinataire = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    titre = models.CharField(max_length=255)
    contenu = models.CharField(max_length=255, blank=True)
    lu = models.BooleanField(default=False)
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-cree_le"]


#EbaJioloLewis
