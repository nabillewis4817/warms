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
    class Niveau(models.TextChoices):
        INFO = "info", "Info"
        RAPPEL = "rappel", "Rappel"
        MESSAGE = "message", "Message"
        CRITIQUE = "critique", "Critique"

    """
    Notification applicative de base (push/email branchés ensuite).
    """

    destinataire = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    titre = models.CharField(max_length=255)
    contenu = models.CharField(max_length=255, blank=True)
    niveau = models.CharField(max_length=16, choices=Niveau.choices, default=Niveau.INFO)
    lu = models.BooleanField(default=False)
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-cree_le"]


class Rappel(models.Model):
    """
    Rappel personnalisable programmé par l'utilisateur lui-même (ex: un
    patient qui souhaite être notifié de prendre un médicament, ou de son
    prochain rendez-vous), distinct des `NotificationInterne` générées
    automatiquement par le système.

    La diffusion reste interne à l'app (notification locale planifiée côté
    mobile) : ce modèle ne fait que stocker la programmation pour qu'elle
    survive à une réinstallation/reconnexion sur un autre appareil.
    """

    class Recurrence(models.TextChoices):
        AUCUNE = "aucune", "Une seule fois"
        QUOTIDIEN = "quotidien", "Tous les jours"
        HEBDOMADAIRE = "hebdomadaire", "Toutes les semaines"
        MENSUEL = "mensuel", "Tous les mois"

    utilisateur = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="rappels"
    )
    titre = models.CharField(max_length=255)
    message = models.CharField(max_length=500, blank=True)
    date_heure = models.DateTimeField(help_text="Date et heure de la prochaine occurrence du rappel.")
    recurrence = models.CharField(max_length=16, choices=Recurrence.choices, default=Recurrence.AUCUNE)
    actif = models.BooleanField(default=True)
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["date_heure"]

    def __str__(self) -> str:
        return f"Rappel {self.titre} — {self.utilisateur} ({self.date_heure:%d/%m/%Y %H:%M})"


#EbaJioloLewis
