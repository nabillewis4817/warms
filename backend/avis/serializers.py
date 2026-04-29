from rest_framework import serializers
from .models import Avis, StatistiquesAvis, MotifSignalement


class AvisSerializer(serializers.ModelSerializer):
    """Serializer principal pour les avis"""
    
    patient_nom = serializers.CharField(source='patient_nom', read_only=True)
    patient_email = serializers.CharField(source='patient_email', read_only=True)
    type_label = serializers.CharField(source='type_label', read_only=True)
    statut_label = serializers.CharField(source='statut_label', read_only=True)
    a_reponse = serializers.BooleanField(source='a_reponse', read_only=True)
    est_recent = serializers.BooleanField(source='est_recent', read_only=True)
    
    # Informations de modération
    modere_par_nom = serializers.CharField(source='modere_par.get_full_name', read_only=True)
    reponse_par_nom = serializers.CharField(source='reponse_par.get_full_name', read_only=True)
    
    class Meta:
        model = Avis
        fields = [
            'id',
            'patient',
            'patient_nom',
            'patient_email',
            'type_avis',
            'type_label',
            'note',
            'titre',
            'commentaire',
            'points_positifs',
            'points_negatifs',
            'suggestions',
            'statut',
            'statut_label',
            'modere_par',
            'modere_par_nom',
            'date_moderation',
            'motif_moderation',
            'nombre_signalements',
            'reponse_personnel',
            'reponse_par',
            'reponse_par_nom',
            'date_reponse',
            'a_reponse',
            'est_recent',
            'cree_le',
            'modifie_le',
        ]
        read_only_fields = [
            'id', 'patient', 'nombre_signalements', 'cree_le', 'modifie_le',
            'date_moderation', 'date_reponse', 'modere_par', 'reponse_par'
        ]


class AvisCreateSerializer(serializers.ModelSerializer):
    """Serializer pour la création d'avis"""
    
    class Meta:
        model = Avis
        fields = [
            'type_avis',
            'note',
            'titre',
            'commentaire',
            'points_positifs',
            'points_negatifs',
            'suggestions',
        ]
    
    def validate_note(self, value):
        """Validation de la note"""
        if value < 1 or value > 5:
            raise serializers.ValidationError("La note doit être entre 1 et 5.")
        return value
    
    def create(self, validated_data):
        """Crée un avis avec l'utilisateur connecté"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['patient'] = request.user
        
        return super().create(validated_data)


class AvisUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour la mise à jour d'avis"""
    
    class Meta:
        model = Avis
        fields = [
            'type_avis',
            'note',
            'titre',
            'commentaire',
            'points_positifs',
            'points_negatifs',
            'suggestions',
        ]
    
    def validate_note(self, value):
        """Validation de la note"""
        if value < 1 or value > 5:
            raise serializers.ValidationError("La note doit être entre 1 et 5.")
        return value


class AvisModerationSerializer(serializers.ModelSerializer):
    """Serializer pour la modération des avis"""
    
    class Meta:
        model = Avis
        fields = [
            'statut',
            'motif_moderation',
            'reponse_personnel',
        ]


class AvisListSerializer(serializers.ModelSerializer):
    """Serializer simplifié pour les listes"""
    
    patient_nom = serializers.CharField(source='patient_nom', read_only=True)
    type_label = serializers.CharField(source='type_label', read_only=True)
    a_reponse = serializers.BooleanField(source='a_reponse', read_only=True)
    est_recent = serializers.BooleanField(source='est_recent', read_only=True)
    
    class Meta:
        model = Avis
        fields = [
            'id',
            'patient_nom',
            'type_avis',
            'type_label',
            'note',
            'titre',
            'statut',
            'a_reponse',
            'est_recent',
            'cree_le',
        ]


class StatistiquesAvisSerializer(serializers.ModelSerializer):
    """Serializer pour les statistiques des avis"""
    
    class Meta:
        model = StatistiquesAvis
        fields = [
            'id',
            'periode',
            'type_avis',
            'nombre_avis',
            'note_moyenne',
            'note_distribution',
            'cree_le',
            'modifie_le',
        ]
        read_only_fields = ['id', 'cree_le', 'modifie_le']


class MotifSignalementSerializer(serializers.ModelSerializer):
    """Serializer pour les motifs de signalement"""
    
    class Meta:
        model = MotifSignalement
        fields = [
            'id',
            'nom',
            'description',
            'actif',
            'cree_le',
        ]
        read_only_fields = ['id', 'cree_le']


class AvisReponseSerializer(serializers.ModelSerializer):
    """Serializer pour répondre à un avis"""
    
    class Meta:
        model = Avis
        fields = [
            'reponse_personnel',
        ]
    
    def update(self, instance, validated_data):
        """Met à jour la réponse avec l'utilisateur connecté"""
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            validated_data['reponse_par'] = request.user
            validated_data['date_reponse'] = timezone.now()
        
        return super().update(instance, validated_data)
