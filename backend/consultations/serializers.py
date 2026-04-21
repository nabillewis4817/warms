from rest_framework import serializers

from .models import ActeRealise, Consultation, PhotoClinique, SchemaDentaire


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


#EbaJioloLewis
