from rest_framework import serializers
from .models_personnel import Personnel, HistoriqueStatut, Presence


class PersonnelSerializer(serializers.ModelSerializer):
    """Serializer pour le personnel avec toutes les informations nécessaires"""
    
    nom = serializers.CharField(source='utilisateur.last_name', read_only=True)
    prenom = serializers.CharField(source='utilisateur.first_name', read_only=True)
    email = serializers.CharField(source='utilisateur.email', read_only=True)
    telephone = serializers.CharField(source='utilisateur.telephone', read_only=True)
    role = serializers.CharField(source='utilisateur.role', read_only=True)
    photo = serializers.ImageField(source='utilisateur.photo_profil', read_only=True)
    
    # Champs calculés
    nom_complet = serializers.CharField(read_only=True)
    anciennete = serializers.IntegerField(read_only=True)
    role_label = serializers.CharField(read_only=True)
    
    class Meta:
        model = Personnel
        fields = [
            'id',
            'matricule',
            'nom',
            'prenom',
            'email',
            'telephone',
            'telephone_professionnel',
            'email_professionnel',
            'role',
            'role_label',
            'service',
            'specialite',
            'numero_ordre',
            'date_embauche',
            'statut',
            'nom_complet',
            'anciennete',
            'competences',
            'certifications',
            'derniere_connexion',
            'photo',
            'horaire_travail',
            'cree_le',
            'modifie_le',
        ]
        read_only_fields = ['id', 'matricule', 'cree_le', 'modifie_le']


class PersonnelCreateSerializer(serializers.ModelSerializer):
    """Serializer pour la création de personnel"""
    
    utilisateur = serializers.PrimaryKeyRelatedField(
        queryset=serializers.CurrentUserDefault().get_queryset()
    )
    
    class Meta:
        model = Personnel
        fields = [
            'utilisateur',
            'matricule',
            'date_embauche',
            'service',
            'specialite',
            'numero_ordre',
            'telephone_professionnel',
            'email_professionnel',
            'statut',
            'horaire_travail',
            'competences',
            'certifications',
        ]


class PersonnelUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour la mise à jour de personnel"""
    
    class Meta:
        model = Personnel
        fields = [
            'service',
            'specialite',
            'numero_ordre',
            'telephone_professionnel',
            'email_professionnel',
            'statut',
            'horaire_travail',
            'competences',
            'certifications',
        ]


class HistoriqueStatutSerializer(serializers.ModelSerializer):
    """Serializer pour l'historique des changements de statut"""
    
    personnel_nom = serializers.CharField(source='personnel.nom_complet', read_only=True)
    modifie_par_nom = serializers.CharField(source='modifie_par.get_full_name', read_only=True)
    
    class Meta:
        model = HistoriqueStatut
        fields = [
            'id',
            'personnel',
            'personnel_nom',
            'ancien_statut',
            'nouveau_statut',
            'raison',
            'modifie_par',
            'modifie_par_nom',
            'date_changement',
        ]
        read_only_fields = ['id', 'date_changement']


class PresenceSerializer(serializers.ModelSerializer):
    """Serializer pour le suivi de présence"""
    
    personnel_nom = serializers.CharField(source='personnel.nom_complet', read_only=True)
    
    class Meta:
        model = Presence
        fields = [
            'id',
            'personnel',
            'personnel_nom',
            'date',
            'heure_arrivee',
            'heure_depart',
            'statut',
            'notes',
        ]
        read_only_fields = ['id']


class PersonnelListSerializer(serializers.ModelSerializer):
    """Serializer simplifié pour les listes"""
    
    nom_complet = serializers.CharField(read_only=True)
    role = serializers.CharField(source='utilisateur.role', read_only=True)
    email = serializers.CharField(source='utilisateur.email', read_only=True)
    
    class Meta:
        model = Personnel
        fields = [
            'id',
            'matricule',
            'nom_complet',
            'role',
            'email',
            'service',
            'specialite',
            'statut',
            'date_embauche',
            'derniere_connexion',
        ]
