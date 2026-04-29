from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()


class Personnel(models.Model):
    """
    Modèle pour gérer les informations détaillées du personnel médical
    """
    
    class Statut(models.TextChoices):
        ACTIF = "actif", "Actif"
        INACTIF = "inactif", "Inactif"
        EN_CONGE = "en_conge", "En congé"
        SUSPENDU = "suspendu", "Suspendu"
    
    utilisateur = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name="personnel_info"
    )
    
    # Informations professionnelles
    matricule = models.CharField(
        max_length=20,
        unique=True,
        help_text="Matricule unique du personnel"
    )
    
    date_embauche = models.DateField(
        help_text="Date d'embauche du personnel"
    )
    
    service = models.CharField(
        max_length=100,
        choices=[
            ('chirurgie_generale', 'Chirurgie générale'),
            ('orthodontie', 'Orthodontie'),
            ('pediatrie', 'Pédiatrie'),
            ('administration', 'Administration'),
            ('radiologie', 'Radiologie'),
            ('laboratoire', 'Laboratoire'),
        ],
        help_text="Service de rattachement"
    )
    
    specialite = models.CharField(
        max_length=100,
        blank=True,
        help_text="Spécialité médicale"
    )
    
    numero_ordre = models.CharField(
        max_length=50,
        blank=True,
        help_text="Numéro d'ordre professionnel"
    )
    
    # Informations de contact
    telephone_professionnel = models.CharField(
        max_length=20,
        blank=True,
        help_text="Téléphone professionnel"
    )
    
    email_professionnel = models.EmailField(
        blank=True,
        help_text="Email professionnel"
    )
    
    # Statut et horaires
    statut = models.CharField(
        max_length=20,
        choices=Statut.choices,
        default=Statut.ACTIF
    )
    
    horaire_travail = models.JSONField(
        default=dict,
        blank=True,
        help_text="Horaires de travail par jour"
    )
    
    # Compétences et certifications
    competences = models.JSONField(
        default=list,
        blank=True,
        help_text="Liste des compétences"
    )
    
    certifications = models.JSONField(
        default=list,
        blank=True,
        help_text="Certifications et formations"
    )
    
    # Dernière connexion
    derniere_connexion = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Dernière date de connexion"
    )
    
    # Metadata
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['utilisateur__last_name', 'utilisateur__first_name']
        indexes = [
            models.Index(fields=['service']),
            models.Index(fields=['statut']),
            models.Index(fields=['date_embauche']),
        ]
    
    def __str__(self):
        return f"{self.utilisateur.get_full_name()} - {self.service}"
    
    @property
    def nom_complet(self):
        """Retourne le nom complet du personnel"""
        return self.utilisateur.get_full_name()
    
    @property
    def email(self):
        """Retourne l'email de l'utilisateur"""
        return self.utilisateur.email
    
    @property
    def telephone(self):
        """Retourne le téléphone professionnel ou personnel"""
        return self.telephone_professionnel or self.utilisateur.telephone
    
    @property
    def role_label(self):
        """Retourne le label du rôle"""
        return self.utilisateur.get_role_display()
    
    @property
    def anciennete(self):
        """Calcule l'ancienneté en années"""
        from datetime import date
        today = date.today()
        return today.year - self.date_embauche.year - (
            (today.month, today.day) < (self.date_embauche.month, self.date_embauche.day)
        )


class HistoriqueStatut(models.Model):
    """
    Historique des changements de statut du personnel
    """
    
    personnel = models.ForeignKey(
        Personnel,
        on_delete=models.CASCADE,
        related_name="historique_statuts"
    )
    
    ancien_statut = models.CharField(max_length=20)
    nouveau_statut = models.CharField(max_length=20)
    raison = models.TextField(blank=True)
    modifie_par = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True
    )
    date_changement = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-date_changement']
    
    def __str__(self):
        return f"{self.personnel} - {self.ancien_statut} → {self.nouveau_statut}"


class Presence(models.Model):
    """
    Suivi de la présence du personnel
    """
    
    personnel = models.ForeignKey(
        Personnel,
        on_delete=models.CASCADE,
        related_name="presences"
    )
    
    date = models.DateField()
    heure_arrivee = models.TimeField(null=True, blank=True)
    heure_depart = models.TimeField(null=True, blank=True)
    statut = models.CharField(
        max_length=20,
        choices=[
            ('present', 'Présent'),
            ('absent', 'Absent'),
            ('retard', 'Retard'),
            ('conge', 'Congé'),
            ('maladie', 'Maladie'),
        ],
        default='present'
    )
    notes = models.TextField(blank=True)
    
    class Meta:
        ordering = ['-date']
        unique_together = ['personnel', 'date']
    
    def __str__(self):
        return f"{self.personnel} - {self.date} - {self.statut}"
