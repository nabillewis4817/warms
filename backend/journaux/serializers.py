from rest_framework import serializers
from django.contrib.auth import get_user_model

from .models import LogActivite

User = get_user_model()


class LogActiviteSerializer(serializers.ModelSerializer):
    """Serializer pour les logs d'activité avec toutes les informations nécessaires"""
    
    utilisateur = serializers.SerializerMethodField()
    date = serializers.SerializerMethodField()
    icone = serializers.SerializerMethodField()
    
    class Meta:
        model = LogActivite
        fields = [
            "id",
            "utilisateur",
            "action",
            "type_action",
            "details",
            "date",
            "icone",
            "objet_type",
            "objet_id",
            "metadata",
            "adresse_ip",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = fields

    def get_utilisateur(self, obj):
        """Retourne le nom complet de l'utilisateur"""
        return obj.utilisateur_nom

    def get_date(self, obj):
        """Retourne la date formatée"""
        return obj.cree_le.strftime("%Y-%m-%d %H:%M")

    def get_icone(self, obj):
        """Retourne l'icône associée"""
        return obj.icone_type


class LogActiviteCreateSerializer(serializers.ModelSerializer):
    """Serializer pour la création de logs d'activité"""
    
    class Meta:
        model = LogActivite
        fields = [
            "action",
            "type_action",
            "details",
            "objet_type",
            "objet_id",
            "metadata",
            "adresse_ip",
            "user_agent",
        ]

    def create(self, validated_data):
        """Crée un log d'activité avec l'utilisateur connecté"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['acteur'] = request.user
        
        return super().create(validated_data)


#EbaJioloLewis
