from rest_framework import serializers
from .models import (
    ConversationIA, MessageIA, RechercheIA, 
    AnalyseMedicale, DocumentOCR, PreferenceIA
)

class MessageIASerializer(serializers.ModelSerializer):
    class Meta:
        model = MessageIA
        fields = ['id', 'contenu', 'type_message', 'timestamp', 'metadonnees']

class ConversationIASerializer(serializers.ModelSerializer):
    messages = MessageIASerializer(many=True, read_only=True)
    
    class Meta:
        model = ConversationIA
        fields = ['id', 'plateforme', 'cree_le', 'modifie_le', 'contexte', 'messages']

class RechercheIASerializer(serializers.ModelSerializer):
    class Meta:
        model = RechercheIA
        fields = ['id', 'query', 'plateforme', 'resultat', 'timestamp', 'contexte']

class AnalyseMedicaleSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnalyseMedicale
        fields = [
            'id', 'patient_id', 'type_analyse', 'donnees_entree', 
            'resultat', 'confiance', 'plateforme', 'cree_le'
        ]

class DocumentOCRSerializer(serializers.ModelSerializer):
    class Meta:
        model = DocumentOCR
        fields = [
            'id', 'fichier_original', 'fichier_traite', 'texte_extrait',
            'metadonnees', 'confiance', 'plateforme', 'cree_le'
        ]

class PreferenceIASerializer(serializers.ModelSerializer):
    class Meta:
        model = PreferenceIA
        fields = [
            'langue', 'voix_activee', 'notifications_ia', 
            'mode_expert', 'sauvegarder_conversations'
        ]
