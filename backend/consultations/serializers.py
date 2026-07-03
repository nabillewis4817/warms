from rest_framework import serializers

from patients.models import DossierPatient
from .models import ActeRealise, Appel, Consultation, PhotoClinique, SchemaDentaire, SuiviDouleur, TauxAbsenteisme


class ActeRealiseSerializer(serializers.ModelSerializer):
    class Meta:
        model = ActeRealise
        fields = ["id", "consultation", "libelle", "description", "dent", "cree_le"]
        read_only_fields = ["cree_le"]


class SchemaDentaireSerializer(serializers.ModelSerializer):
    class Meta:
        model = SchemaDentaire
        fields = ["id", "consultation", "donnees", "cree_le", "modifie_le"]
        read_only_fields = ["cree_le", "modifie_le"]


class PhotoCliniqueSerializer(serializers.ModelSerializer):
    class Meta:
        model = PhotoClinique
        fields = ["id", "consultation", "fichier", "type_photo", "commentaire", "cree_le"]
        read_only_fields = ["cree_le"]


class ConsultationSerializer(serializers.ModelSerializer):
    actes = ActeRealiseSerializer(many=True, read_only=True)
    schema_dentaire = SchemaDentaireSerializer(read_only=True)
    photos = PhotoCliniqueSerializer(many=True, read_only=True)

    patient_nom = serializers.CharField(source="patient.nom", read_only=True)
    patient_prenom = serializers.CharField(source="patient.prenom", read_only=True)

    # dossier est optionnel : perform_create le récupère automatiquement depuis le patient
    dossier = serializers.PrimaryKeyRelatedField(
        queryset=DossierPatient.objects.all(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = Consultation
        fields = [
            "id",
            "patient",
            "patient_prenom",
            "patient_nom",
            "dossier",
            "rendez_vous",
            "praticien",
            "date",
            "motif",
            "observations",
            "diagnostic",
            "notes",
            "actes",
            "schema_dentaire",
            "photos",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = ["cree_le", "modifie_le"]


class AppelSerializer(serializers.ModelSerializer):
    """Serializer pour la gestion des appels et absences"""
    
    patient_nom = serializers.CharField(source="patient.nom", read_only=True)
    patient_prenom = serializers.CharField(source="patient.prenom", read_only=True)
    praticien_nom = serializers.CharField(source="praticien.get_full_name", read_only=True)
    statut_display = serializers.CharField(source="get_statut_display", read_only=True)
    
    # Champs calculés
    est_present = serializers.BooleanField(read_only=True)
    est_absent = serializers.BooleanField(read_only=True)
    est_en_retard = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = Appel
        fields = [
            "id",
            "patient",
            "patient_nom",
            "patient_prenom",
            "praticien",
            "praticien_nom",
            "rendez_vous",
            "date_appel",
            "heure_appel",
            "statut",
            "statut_display",
            "motif_absence",
            "justificatif_fourni",
            "fichier_justificatif",
            "duree_retard",
            "notes_appel",
            "notes_suivi",
            "cree_par",
            "cree_le",
            "modifie_le",
            "est_present",
            "est_absent",
            "est_en_retard",
        ]
        read_only_fields = ["heure_appel", "cree_le", "modifie_le"]


class AppelCreateSerializer(serializers.ModelSerializer):
    """Serializer pour la création d'appels (plus restrictif)"""
    
    class Meta:
        model = Appel
        fields = [
            "patient",
            "praticien",
            "rendez_vous",
            "date_appel",
            "statut",
            "motif_absence",
            "justificatif_fourni",
            "fichier_justificatif",
            "duree_retard",
            "notes_appel",
        ]
    
    def validate(self, data):
        """Validation personnalisée pour la création d'appels"""
        statut = data.get('statut')
        
        # Si le statut est absent, un motif est requis
        if statut in ['absent_justifie', 'absent_non_justifie'] and not data.get('motif_absence'):
            raise serializers.ValidationError(
                "Un motif d'absence est requis pour les absences."
            )
        
        # Si le statut est absent_justifie, un justificatif est requis
        if statut == 'absent_justifie' and not data.get('justificatif_fourni'):
            raise serializers.ValidationError(
                "Un justificatif est requis pour les absences justifiées."
            )
        
        # Si le statut est en_retard, une durée de retard est requise
        if statut == 'en_retard' and not data.get('duree_retard'):
            raise serializers.ValidationError(
                "Une durée de retard est requise pour les retards."
            )
        
        return data


class TauxAbsenteismeSerializer(serializers.ModelSerializer):
    """Serializer pour les taux d'absentéisme"""

    praticien_nom = serializers.SerializerMethodField()
    type_periode_display = serializers.CharField(source="get_type_periode_display", read_only=True)

    def get_praticien_nom(self, obj) -> str | None:
        if not obj.praticien_id:
            return None
        praticien = obj.praticien
        nom = praticien.get_full_name() if hasattr(praticien, "get_full_name") else ""
        if nom:
            return nom
        return getattr(praticien, "username", None)
    
    class Meta:
        model = TauxAbsenteisme
        fields = [
            "id",
            "periode_debut",
            "periode_fin",
            "praticien",
            "praticien_nom",
            "type_periode",
            "type_periode_display",
            "total_appels",
            "total_presents",
            "total_absents",
            "total_absents_justifies",
            "total_absents_non_justifies",
            "total_en_retard",
            "total_annules",
            "taux_presence",
            "taux_absenteisme",
            "taux_absenteisme_justifie",
            "taux_retard",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = [
            "total_appels",
            "total_presents", 
            "total_absents",
            "total_absents_justifies",
            "total_absents_non_justifies",
            "total_en_retard",
            "total_annules",
            "taux_presence",
            "taux_absenteisme",
            "taux_absenteisme_justifie",
            "taux_retard",
            "cree_le",
            "modifie_le"
        ]


class TauxAbsenteismeCreateSerializer(serializers.ModelSerializer):
    """Serializer pour la création de taux d'absentéisme"""
    
    class Meta:
        model = TauxAbsenteisme
        fields = [
            "periode_debut",
            "periode_fin",
            "praticien",
            "type_periode",
        ]
    
    def validate(self, data):
        """Validation personnalisée pour la création de taux"""
        periode_debut = data.get('periode_debut')
        periode_fin = data.get('periode_fin')
        
        if periode_debut and periode_fin and periode_debut > periode_fin:
            raise serializers.ValidationError(
                "La date de début doit être antérieure à la date de fin."
            )
        
        return data


class SuiviDouleurSerializer(serializers.ModelSerializer):
    class Meta:
        model = SuiviDouleur
        fields = ['id', 'consultation', 'patient', 'date_signalement', 'intensite', 'description', 'localisation', 'type_douleur', 'traitement_pris']
        read_only_fields = ['id', 'date_signalement']


#EbaJioloLewis
