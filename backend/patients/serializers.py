from rest_framework import serializers

from .models import DossierPatient, PageCarnet, Patient, PieceJointeDossier


class PatientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Patient
        fields = [
            "id",
            "prenom",
            "nom",
            "date_naissance",
            "sexe",
            "telephone",
            "email",
            "adresse",
            "infirmiere_referente",
            "actif",
            "cree_le",
            "modifie_le",
        ]


class PageCarnetSerializer(serializers.ModelSerializer):
    class Meta:
        model = PageCarnet
        fields = [
            "id",
            "dossier",
            "numero_page",
            "contenu",
            "cree_le",
            "modifie_le",
        ]


class PieceJointeDossierSerializer(serializers.ModelSerializer):
    class Meta:
        model = PieceJointeDossier
        fields = ["id", "dossier", "fichier", "libelle", "cree_le"]


class DossierPatientSerializer(serializers.ModelSerializer):
    patient = PatientSerializer(read_only=True)
    pages = PageCarnetSerializer(many=True, read_only=True)
    pieces_jointes = PieceJointeDossierSerializer(many=True, read_only=True)

    class Meta:
        model = DossierPatient
        fields = [
            "id",
            "patient",
            "numero_dossier",
            "notes_medicales",
            "antecedents",
            "allergies",
            "pages",
            "pieces_jointes",
            "cree_le",
            "modifie_le",
        ]


class DossierPatientCreateSerializer(serializers.ModelSerializer):
    """
    Création guidée: on crée le Patient + son Dossier en une seule requête.
    """

    patient = PatientSerializer()

    class Meta:
        model = DossierPatient
        fields = [
            "id",
            "patient",
            "numero_dossier",
            "notes_medicales",
            "antecedents",
            "allergies",
        ]

    def create(self, validated_data):
        patient_data = validated_data.pop("patient")
        patient = Patient.objects.create(**patient_data)
        dossier = DossierPatient.objects.create(patient=patient, **validated_data)
        return dossier
