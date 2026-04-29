from django.db import models
from django.contrib.auth import get_user_model
import json

User = get_user_model()

class ConversationIA(models.Model):
    """Modèle pour les conversations IA partagées entre Web et Mobile"""
    id = models.CharField(max_length=32, primary_key=True)  # ID unique de conversation
    utilisateur = models.ForeignKey(User, on_delete=models.CASCADE)
    plateforme = models.CharField(max_length=10, choices=[('web', 'Web'), ('mobile', 'Mobile')])
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    contexte = models.JSONField(default=dict)  # Contexte médical, symptômes, etc.
    
    class Meta:
        ordering = ['-modifie_le']

class MessageIA(models.Model):
    """Messages dans une conversation IA"""
    conversation = models.ForeignKey(ConversationIA, on_delete=models.CASCADE, related_name='messages')
    contenu = models.TextField()
    type_message = models.CharField(max_length=10, choices=[('user', 'User'), ('ia', 'IA')])
    timestamp = models.DateTimeField(auto_now_add=True)
    metadonnees = models.JSONField(default=dict)  # Sources, confiance, etc.
    
    class Meta:
        ordering = ['timestamp']

class RechercheIA(models.Model):
    """Historique des recherches IA"""
    utilisateur = models.ForeignKey(User, on_delete=models.CASCADE)
    query = models.TextField()
    plateforme = models.CharField(max_length=10, choices=[('web', 'Web'), ('mobile', 'Mobile')])
    resultat = models.JSONField()  # Résultats de recherche, sources
    timestamp = models.DateTimeField(auto_now_add=True)
    contexte = models.JSONField(default=dict)
    
    class Meta:
        ordering = ['-timestamp']

class AnalyseMedicale(models.Model):
    """Analyses médicales générées par IA"""
    utilisateur = models.ForeignKey(User, on_delete=models.CASCADE)
    patient_id = models.IntegerField(null=True, blank=True)  # ID patient si applicable
    type_analyse = models.CharField(max_length=20, choices=[
        ('symptomes', 'Analyse symptômes'),
        ('traitement', 'Suggestion traitement'),
        ('interaction', 'Vérification interactions'),
        ('diagnostic', 'Aide diagnostic')
    ])
    donnees_entree = models.JSONField()
    resultat = models.JSONField()
    confiance = models.FloatField()
    plateforme = models.CharField(max_length=10, choices=[('web', 'Web'), ('mobile', 'Mobile')])
    cree_le = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-cree_le']

class DocumentOCR(models.Model):
    """Documents traités par OCR"""
    utilisateur = models.ForeignKey(User, on_delete=models.CASCADE)
    fichier_original = models.FileField(upload_to='ocr/original/')
    fichier_traite = models.FileField(upload_to='ocr/processed/', null=True, blank=True)
    texte_extrait = models.TextField()
    metadonnees = models.JSONField(default=dict)  # Informations patient, type document, etc.
    confiance = models.FloatField()
    plateforme = models.CharField(max_length=10, choices=[('web', 'Web'), ('mobile', 'Mobile')])
    cree_le = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-cree_le']

class PreferenceIA(models.Model):
    """Préférences IA par utilisateur et plateforme"""
    utilisateur = models.ForeignKey(User, on_delete=models.CASCADE)
    plateforme = models.CharField(max_length=10, choices=[('web', 'Web'), ('mobile', 'Mobile')])
    langue = models.CharField(max_length=5, default='fr')
    voix_activee = models.BooleanField(default=False)
    notifications_ia = models.BooleanField(default=True)
    mode_expert = models.BooleanField(default=False)  # Réponses plus techniques
    sauvegarder_conversations = models.BooleanField(default=True)
    
    class Meta:
        unique_together = ['utilisateur', 'plateforme']
