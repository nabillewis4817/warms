from django.conf import settings
from django.db import models


class LogActivite(models.Model):
    """
    Journalisation complète des actions dans le système WARMS.
    """

    acteur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="logs_activite",
    )

    # Action et type
    action = models.CharField(max_length=100, help_text="Ex: création_patient, modification_consultation")
    type_action = models.CharField(
        max_length=50,
        choices=[
            ('patient', 'Patient'),
            ('consultation', 'Consultation'),
            ('rendez_vous', 'Rendez-vous'),
            ('personnel', 'Personnel'),
            ('systeme', 'Système'),
            ('modification', 'Modification'),
            ('suppression', 'Suppression'),
            ('connexion', 'Connexion'),
            ('ordonnance', 'Ordonnance'),
            ('analyse', 'Analyse'),
        ],
        default='systeme'
    )
    
    # Détails de l'action
    details = models.TextField(blank=True, help_text="Description détaillée de l'action")
    objet_type = models.CharField(max_length=64, blank=True, help_text="Type d'objet concerné")
    objet_id = models.CharField(max_length=64, blank=True, help_text="ID de l'objet concerné")
    
    # Métadonnées étendues
    metadata = models.JSONField(default=dict, blank=True)
    
    # Informations système
    adresse_ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    
    # Timestamps
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-cree_le"]
        indexes = [
            models.Index(fields=["action"]),
            models.Index(fields=["cree_le"]),
        ]

    def __str__(self) -> str:
        who = str(self.acteur) if self.acteur else "Système"
        return f"{self.action} — {who} — {self.cree_le:%d/%m/%Y %H:%M}"

    @property
    def utilisateur_nom(self):
        """Retourne le nom complet de l'utilisateur"""
        if self.acteur:
            return f"{self.acteur.first_name} {self.acteur.last_name}".strip()
        return "Système"

    @property
    def icone_type(self):
        """Retourne l'icône Bootstrap associée au type d'action"""
        icones = {
            'patient': 'bi-person-plus',
            'consultation': 'bi-clipboard2',
            'rendez_vous': 'bi-calendar-check',
            'personnel': 'bi-people',
            'systeme': 'bi-gear',
            'modification': 'bi-pencil',
            'suppression': 'bi-trash',
            'connexion': 'bi-box-arrow-in-right',
            'ordonnance': 'bi-file-medical',
            'analyse': 'bi-graph-up'
        }
        return icones.get(self.type_action, 'bi-circle')


#EbaJioloLewis
