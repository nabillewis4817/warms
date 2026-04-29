from django.conf import settings
from django.db import models

from patients.models import DossierPatient, Patient
from rendez_vous.models import RendezVous


class Consultation(models.Model):
    """
    Consultation / séance clinique.

    Objectif: garder une trace "séance par séance":
    - observations cliniques
    - diagnostic
    - notes du chirurgien-dentiste
    - actes réalisés
    - schéma dentaire (versionné par consultation)
    - photos pré/post-op
    """

    patient = models.ForeignKey(Patient, on_delete=models.PROTECT, related_name="consultations")
    dossier = models.ForeignKey(DossierPatient, on_delete=models.PROTECT, related_name="consultations")

    rendez_vous = models.OneToOneField(
        RendezVous,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="consultation",
        help_text="Rendez-vous associé (si la consultation provient du planning).",
    )

    praticien = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="consultations_praticien",
    )

    date = models.DateTimeField()
    motif = models.CharField(max_length=255, blank=True)

    observations = models.TextField(blank=True)
    diagnostic = models.TextField(blank=True)
    notes = models.TextField(blank=True)

    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-date"]
        indexes = [
            models.Index(fields=["date"]),
        ]

    def __str__(self) -> str:
        return f"Consultation {self.patient} — {self.date:%d/%m/%Y %H:%M}"


class ActeRealise(models.Model):
    """
    Acte/soin effectué pendant la consultation (ex: détartrage, extraction...).
    """

    consultation = models.ForeignKey(Consultation, on_delete=models.CASCADE, related_name="actes")
    libelle = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    dent = models.CharField(
        max_length=16,
        blank=True,
        help_text="Optionnel: dent concernée (notation à préciser plus tard).",
    )
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["id"]

    def __str__(self) -> str:
        return self.libelle


class SchemaDentaire(models.Model):
    """
    Schéma dentaire associé à une consultation.

    Format JSON libre au départ (côté front on stockera l'état du diagramme).
    """

    consultation = models.OneToOneField(
        Consultation, on_delete=models.CASCADE, related_name="schema_dentaire"
    )
    donnees = models.JSONField(default=dict, blank=True)
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f"Schéma — {self.consultation}"


class PhotoClinique(models.Model):
    """
    Photo clinique pré/post opératoire ou image de contrôle.
    """

    class TypePhoto(models.TextChoices):
        PRE_OP = "pre_op", "Pré-opératoire"
        POST_OP = "post_op", "Post-opératoire"
        AUTRE = "autre", "Autre"

    consultation = models.ForeignKey(
        Consultation, on_delete=models.CASCADE, related_name="photos"
    )
    fichier = models.ImageField(upload_to="consultations/photos/")
    type_photo = models.CharField(max_length=16, choices=TypePhoto.choices, default=TypePhoto.AUTRE)
    commentaire = models.CharField(max_length=255, blank=True)
    cree_le = models.DateTimeField(auto_now_add=True)

    def __str__(self) -> str:
        return f"Photo {self.get_type_photo_display()} — {self.consultation}"


class Appel(models.Model):
    """
    Gestion des appels dans la clinique pour suivre l'absentéisme.
    
    Permet de faire l'appel des patients pour chaque journée de consultation
    et de suivre les présences/absences.
    """
    
    class StatutAppel(models.TextChoices):
        PRESENT = "present", "Présent"
        ABSENT_JUSTIFIE = "absent_justifie", "Absent (justifié)"
        ABSENT_NON_JUSTIFIE = "absent_non_justifie", "Absent (non justifié)"
        EN_RETARD = "en_retard", "En retard"
        ANNULE = "annule", "Annulé"
        EN_ATTENTE = "en_attente", "En attente"
    
    # Relations
    patient = models.ForeignKey(
        Patient, 
        on_delete=models.CASCADE, 
        related_name="appels"
    )
    praticien = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="appels_effectues"
    )
    rendez_vous = models.ForeignKey(
        'rendez_vous.RendezVous',
        on_delete=models.CASCADE,
        related_name="appels",
        null=True,
        blank=True
    )
    
    # Informations de l'appel
    date_appel = models.DateField()
    heure_appel = models.TimeField(auto_now_add=True)
    statut = models.CharField(
        max_length=20, 
        choices=StatutAppel.choices, 
        default=StatutAppel.EN_ATTENTE
    )
    
    # Informations sur l'absence
    motif_absence = models.TextField(
        blank=True,
        help_text="Motif de l'absence si applicable"
    )
    justificatif_fourni = models.BooleanField(
        default=False,
        help_text="Un justificatif a été fourni pour l'absence"
    )
    fichier_justificatif = models.FileField(
        upload_to="appels/justificatifs/",
        blank=True,
        null=True,
        help_text="Fichier du justificatif d'absence"
    )
    
    # Informations sur le retard
    duree_retard = models.DurationField(
        blank=True,
        null=True,
        help_text="Durée du retard si en retard"
    )
    
    # Notes et observations
    notes_appel = models.TextField(
        blank=True,
        help_text="Notes prises lors de l'appel"
    )
    notes_suivi = models.TextField(
        blank=True,
        help_text="Notes de suivi après l'appel"
    )
    
    # Métadonnées
    cree_par = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="appels_crees"
    )
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ["-date_appel", "-heure_appel"]
        indexes = [
            models.Index(fields=["date_appel"]),
            models.Index(fields=["patient", "date_appel"]),
            models.Index(fields=["statut"]),
        ]
        unique_together = ["patient", "date_appel", "rendez_vous"]
        verbose_name = "Appel"
        verbose_name_plural = "Appels"
    
    def __str__(self) -> str:
        return f"Appel {self.patient} — {self.date_appel} ({self.get_statut_display()})"
    
    @property
    def est_present(self) -> bool:
        """Vérifie si le patient est présent"""
        return self.statut == self.StatutAppel.PRESENT
    
    @property
    def est_absent(self) -> bool:
        """Vérifie si le patient est absent"""
        return self.statut in [
            self.StatutAppel.ABSENT_JUSTIFIE,
            self.StatutAppel.ABSENT_NON_JUSTIFIE
        ]
    
    @property
    def est_en_retard(self) -> bool:
        """Vérifie si le patient est en retard"""
        return self.statut == self.StatutAppel.EN_RETARD


class TauxAbsenteisme(models.Model):
    """
    Statistiques et taux d'absentéisme pour le suivi et les rapports.
    """
    
    # Période concernée
    periode_debut = models.DateField()
    periode_fin = models.DateField()
    
    # Filtres optionnels
    praticien = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="taux_absenteisme",
        null=True,
        blank=True,
        help_text="Filtrer par praticien (optionnel)"
    )
    type_periode = models.CharField(
        max_length=10,
        choices=[
            ('jour', 'Journalier'),
            ('semaine', 'Hebdomadaire'),
            ('mois', 'Mensuel'),
            ('annee', 'Annuel'),
        ],
        default='mois',
        help_text="Type de période pour le calcul"
    )
    
    # Statistiques calculées
    total_appels = models.IntegerField(default=0)
    total_presents = models.IntegerField(default=0)
    total_absents = models.IntegerField(default=0)
    total_absents_justifies = models.IntegerField(default=0)
    total_absents_non_justifies = models.IntegerField(default=0)
    total_en_retard = models.IntegerField(default=0)
    total_annules = models.IntegerField(default=0)
    
    # Taux calculés (en pourcentage)
    taux_presence = models.FloatField(default=0.0, help_text="Taux de présence (%)")
    taux_absenteisme = models.FloatField(default=0.0, help_text="Taux d'absentéisme (%)")
    taux_absenteisme_justifie = models.FloatField(default=0.0, help_text="Taux d'absentéisme justifié (%)")
    taux_retard = models.FloatField(default=0.0, help_text="Taux de retard (%)")
    
    # Métadonnées
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ["-periode_debut"]
        indexes = [
            models.Index(fields=["periode_debut", "periode_fin"]),
            models.Index(fields=["type_periode"]),
            models.Index(fields=["praticien"]),
        ]
        unique_together = ["periode_debut", "periode_fin", "praticien", "type_periode"]
        verbose_name = "Taux d'absentéisme"
        verbose_name_plural = "Taux d'absentéisme"
    
    def __str__(self) -> str:
        praticien_str = f" — {self.praticien}" if self.praticien else ""
        return f"Taux {self.type_periode} {self.periode_debut} - {self.periode_fin}{praticien_str}"
    
    def calculer_taux(self):
        """Calcule les taux d'absentéisme basés sur les appels de la période"""
        from django.db.models import Count, Q
        
        # Filtrer les appels pour la période
        appels = Appel.objects.filter(
            date_appel__range=[self.periode_debut, self.periode_fin]
        )
        
        if self.praticien:
            appels = appels.filter(praticien=self.praticien)
        
        # Compter par statut
        stats = appels.aggregate(
            total=Count('id'),
            presents=Count('id', filter=Q(statut='present')),
            absents=Count('id', filter=Q(statut__in=['absent_justifie', 'absent_non_justifie'])),
            absents_justifies=Count('id', filter=Q(statut='absent_justifie')),
            absents_non_justifies=Count('id', filter=Q(statut='absent_non_justifie')),
            en_retard=Count('id', filter=Q(statut='en_retard')),
            annules=Count('id', filter=Q(statut='annule')),
        )
        
        # Mettre à jour les statistiques
        self.total_appels = stats['total'] or 0
        self.total_presents = stats['presents'] or 0
        self.total_absents = stats['absents'] or 0
        self.total_absents_justifies = stats['absents_justifies'] or 0
        self.total_absents_non_justifies = stats['absents_non_justifies'] or 0
        self.total_en_retard = stats['en_retard'] or 0
        self.total_annules = stats['annules'] or 0
        
        # Calculer les taux
        if self.total_appels > 0:
            self.taux_presence = (self.total_presents / self.total_appels) * 100
            self.taux_absenteisme = (self.total_absents / self.total_appels) * 100
            self.taux_absenteisme_justifie = (self.total_absents_justifies / self.total_appels) * 100
            self.taux_retard = (self.total_en_retard / self.total_appels) * 100
        else:
            self.taux_presence = 0.0
            self.taux_absenteisme = 0.0
            self.taux_absenteisme_justifie = 0.0
            self.taux_retard = 0.0
        
        self.save()


#EbaJioloLewis
