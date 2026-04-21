from django.conf import settings
from django.db import models

from consultations.models import Consultation
from patients.models import DossierPatient, Patient


class OCRImportCarnet(models.Model):
    """
    Trace d'import OCR depuis l'app mobile (photo de carnet papier).
    """

    patient = models.ForeignKey(
        Patient, on_delete=models.SET_NULL, null=True, blank=True, related_name="imports_ocr"
    )
    dossier = models.ForeignKey(
        DossierPatient, on_delete=models.SET_NULL, null=True, blank=True, related_name="imports_ocr"
    )
    image_source = models.ImageField(upload_to="ocr/carnets/", null=True, blank=True)
    texte_extrait = models.TextField(blank=True)
    cree_par = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True
    )
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-cree_le"]


class RecommandationIA(models.Model):
    """
    Recommandation médicale/administrative générée automatiquement.
    """

    class TypeRecommandation(models.TextChoices):
        RAPPEL = "rappel", "Rappel"
        CONTROLE = "controle", "Contrôle"
        ALERTE = "alerte", "Alerte"

    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="recommandations_ia")
    type_recommandation = models.CharField(max_length=16, choices=TypeRecommandation.choices)
    message = models.CharField(max_length=255)
    score_confiance = models.FloatField(default=0.5)
    resolue = models.BooleanField(default=False)
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-cree_le"]


class CompteRenduIA(models.Model):
    """
    Compte-rendu généré à partir d'une consultation.
    """

    consultation = models.OneToOneField(
        Consultation, on_delete=models.CASCADE, related_name="compte_rendu_ia"
    )
    contenu = models.TextField()
    genere_par = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True
    )
    cree_le = models.DateTimeField(auto_now_add=True)


class MessageAssistantIA(models.Model):
    """
    Message de chat contextuel lié à un dossier patient.
    """

    dossier = models.ForeignKey(DossierPatient, on_delete=models.CASCADE, related_name="messages_ia")
    auteur = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True
    )
    question = models.TextField()
    reponse = models.TextField()
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-cree_le"]


#EbaJioloLewis
