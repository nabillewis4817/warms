from django.db import models
from django.contrib.auth import get_user_model
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone

User = get_user_model()


class Avis(models.Model):
    """
    Modèle pour les avis et évaluations des patients
    """
    
    class TypeAvis(models.TextChoices):
        CONSULTATION = "consultation", "Consultation"
        TRAITEMENT = "traitement", "Traitement"
        ACCUEIL = "accueil", "Accueil"
        INSTALLATIONS = "installations", "Installations"
        PERSONNEL = "personnel", "Personnel"
        GENERAL = "general", "Général"
    
    class StatutAvis(models.TextChoices):
        PUBLIE = "publie", "Publié"
        MODERE = "modere", "Modéré"
        MASQUE = "masque", "Masqué"
        SIGNALE = "signale", "Signalé"
    
    # Informations de base
    patient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="avis_donne",
        limit_choices_to={'role': User.Role.PATIENT}
    )
    
    type_avis = models.CharField(
        max_length=20,
        choices=TypeAvis.choices,
        default=TypeAvis.GENERAL
    )
    
    # Évaluation
    note = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        help_text="Note sur 5"
    )
    
    titre = models.CharField(
        max_length=200,
        help_text="Titre de l'avis"
    )
    
    commentaire = models.TextField(
        help_text="Commentaire détaillé"
    )
    
    # Métadonnées
    points_positifs = models.JSONField(
        default=list,
        blank=True,
        help_text="Liste des points positifs"
    )
    
    points_negatifs = models.JSONField(
        default=list,
        blank=True,
        help_text="Liste des points négatifs"
    )
    
    suggestions = models.JSONField(
        default=list,
        blank=True,
        help_text="Suggestions d'amélioration"
    )
    
    # Informations système
    statut = models.CharField(
        max_length=20,
        choices=StatutAvis.choices,
        default=StatutAvis.PUBLIE
    )
    
    modere_par = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="avis_moderes"
    )
    
    date_moderation = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Date de modération"
    )
    
    motif_moderation = models.TextField(
        blank=True,
        help_text="Motif de la modération"
    )
    
    # Signalements
    nombre_signalements = models.IntegerField(default=0)
    signale_par = models.ManyToManyField(
        User,
        blank=True,
        related_name="avis_signales"
    )
    
    # Réponse du personnel
    reponse_personnel = models.TextField(
        blank=True,
        help_text="Réponse du personnel à l'avis"
    )
    
    reponse_par = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="avis_repondus"
    )
    
    date_reponse = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Date de la réponse"
    )
    
    # Timestamps
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-cree_le']
        indexes = [
            models.Index(fields=['type_avis']),
            models.Index(fields=['note']),
            models.Index(fields=['statut']),
            models.Index(fields=['cree_le']),
        ]
    
    def __str__(self):
        return f"Avis de {self.patient.get_full_name()} - {self.note}/5"
    
    @property
    def patient_nom(self):
        """Retourne le nom complet du patient"""
        return self.patient.get_full_name()
    
    @property
    def patient_email(self):
        """Retourne l'email du patient"""
        return self.patient.email
    
    @property
    def type_label(self):
        """Retourne le label du type d'avis"""
        return self.get_type_avis_display()
    
    @property
    def statut_label(self):
        """Retourne le label du statut"""
        return self.get_statut_display()
    
    @property
    def a_reponse(self):
        """Vérifie si l'avis a une réponse"""
        return bool(self.reponse_personnel)
    
    @property
    def est_recent(self):
        """Vérifie si l'avis est récent (moins de 30 jours)"""
        return (timezone.now() - self.cree_le).days <= 30
    
    def peut_etre_signale(self, utilisateur):
        """Vérifie si un utilisateur peut signaler cet avis"""
        if not utilisateur or utilisateur == self.patient:
            return False
        return utilisateur not in self.signale_par.all()
    
    def signaler(self, utilisateur):
        """Signale un avis"""
        if self.peut_etre_signale(utilisateur):
            self.signale_par.add(utilisateur)
            self.nombre_signalements += 1
            
            # Masquer automatiquement si trop de signalements
            if self.nombre_signalements >= 5:
                self.statut = self.StatutAvis.SIGNALE
            
            self.save()
            return True
        return False


class StatistiquesAvis(models.Model):
    """
    Statistiques agrégées des avis par période
    """
    
    periode = models.DateField(help_text="Date de la période")
    type_avis = models.CharField(
        max_length=20,
        choices=Avis.TypeAvis.choices
    )
    
    nombre_avis = models.IntegerField(default=0)
    note_moyenne = models.FloatField(default=0.0)
    note_distribution = models.JSONField(
        default=dict,
        help_text="Distribution des notes {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}"
    )
    
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['periode', 'type_avis']
        ordering = ['-periode']
    
    def __str__(self):
        return f"Stats {self.type_avis} - {self.periode}"


class MotifSignalement(models.Model):
    """
    Motifs de signalement des avis
    """
    
    nom = models.CharField(max_length=100, unique=True)
    description = models.TextField()
    actif = models.BooleanField(default=True)
    
    cree_le = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['nom']
    
    def __str__(self):
        return self.nom
