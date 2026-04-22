import uuid

from django.conf import settings
from django.db import models


class Patient(models.Model):
    class StatutParcours(models.TextChoices):
        NOUVEAU = "nouveau", "Nouveau"
        EN_COURS = "en_cours", "En cours"
        OPERE = "opere", "Opéré"
        TERMINE = "termine", "Terminé"

    """
    Profil patient (données biographiques + lien éventuel vers un compte).
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="patient_profile",
        help_text="Compte utilisateur associé (si le patient se connecte).",
    )

    prenom = models.CharField(max_length=100)
    nom = models.CharField(max_length=100)
    date_naissance = models.DateField(null=True, blank=True)
    sexe = models.CharField(max_length=16, blank=True)

    telephone = models.CharField(max_length=32, blank=True)
    email = models.EmailField(blank=True)
    adresse = models.TextField(blank=True)
    age = models.PositiveIntegerField(null=True, blank=True)
    taille_cm = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    poids_kg = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    symptomes = models.TextField(blank=True)
    consultations_precedentes = models.TextField(blank=True)
    statut_parcours = models.CharField(
        max_length=16, choices=StatutParcours.choices, default=StatutParcours.NOUVEAU
    )

    infirmiere_referente = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="patients_suivis",
        help_text="Infirmière référente (prise en charge / suivi).",
    )

    actif = models.BooleanField(default=True, help_text="Archivé = inactif.")
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["nom", "prenom"]

    def __str__(self) -> str:
        return f"{self.prenom} {self.nom}"


class DossierPatient(models.Model):
    """
    Dossier clinique: 'carnet numérique paginé' + pièces jointes + historique.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.OneToOneField(Patient, on_delete=models.PROTECT, related_name="dossier")

    numero_dossier = models.CharField(
        max_length=32,
        unique=True,
        help_text="Identifiant interne du cabinet (peut être imprimé sur le carnet).",
    )

    notes_medicales = models.TextField(blank=True)
    antecedents = models.TextField(blank=True)
    allergies = models.TextField(blank=True)

    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f"Dossier {self.numero_dossier} - {self.patient}"


class PageCarnet(models.Model):
    """
    Une page du carnet numérique (paginé).

    On garde volontairement un format 'texte riche simple' pour démarrer.
    Les schémas dentaires et actes seront ajoutés dans le module consultations.
    """

    dossier = models.ForeignKey(DossierPatient, on_delete=models.CASCADE, related_name="pages")
    numero_page = models.PositiveIntegerField()
    contenu = models.TextField(blank=True)

    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = [("dossier", "numero_page")]
        ordering = ["numero_page"]

    def __str__(self) -> str:
        return f"{self.dossier.numero_dossier} - page {self.numero_page}"


class PieceJointeDossier(models.Model):
    """
    Photo / scan / document lié au dossier patient.
    """

    dossier = models.ForeignKey(
        DossierPatient, on_delete=models.CASCADE, related_name="pieces_jointes"
    )
    fichier = models.FileField(upload_to="dossiers/pieces_jointes/")
    libelle = models.CharField(max_length=255, blank=True)

    cree_le = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return self.libelle or self.fichier.name


class AvisPatient(models.Model):
    patient = models.ForeignKey(Patient, on_delete=models.CASCADE, related_name="avis")
    auteur = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True
    )
    note = models.PositiveSmallIntegerField(default=5)
    commentaire = models.TextField(blank=True)
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-cree_le"]
