import re

from rest_framework import serializers

from .models import AvisPatient, DossierPatient, PageCarnet, Patient, PieceJointeDossier


class PatientSerializer(serializers.ModelSerializer):
    numero_dossier = serializers.CharField(source="dossier.numero_dossier", read_only=True)
    qr_token = serializers.CharField(source="dossier.qr.token", read_only=True)

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
            "age",
            "taille_cm",
            "poids_kg",
            "symptomes",
            "consultations_precedentes",
            "statut_parcours",
            "infirmiere_referente",
            "numero_dossier",
            "qr_token",
            "actif",
            "cree_le",
            "modifie_le",
        ]

    def validate_telephone(self, value):
        if value and not re.match(r"^\+237\d{9}$", value):
            raise serializers.ValidationError("Le téléphone doit respecter le format +237 suivi de 9 chiffres.")
        return value


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


class AvisPatientSerializer(serializers.ModelSerializer):
    patient_nom = serializers.CharField(source="patient.nom", read_only=True)
    patient_prenom = serializers.CharField(source="patient.prenom", read_only=True)

    class Meta:
        model = AvisPatient
        fields = [
            "id",
            "patient",
            "patient_nom",
            "patient_prenom",
            "auteur",
            "note",
            "commentaire",
            "cree_le",
        ]
        read_only_fields = ["auteur", "cree_le"]
