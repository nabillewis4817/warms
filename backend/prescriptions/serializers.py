from rest_framework import serializers

from .models import LignePrescription, Prescription


class LignePrescriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = LignePrescription
        fields = ["id", "prescription", "medicament", "posologie", "duree", "remarques"]


class PrescriptionSerializer(serializers.ModelSerializer):
    lignes = LignePrescriptionSerializer(many=True, read_only=True)
    patient_nom = serializers.CharField(source="patient.nom", read_only=True)
    patient_prenom = serializers.CharField(source="patient.prenom", read_only=True)

    class Meta:
        model = Prescription
        fields = [
            "id",
            "patient",
            "patient_prenom",
            "patient_nom",
            "dossier",
            "consultation",
            "praticien",
            "titre",
            "note_praticien",
            "lignes",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = ["cree_le", "modifie_le"]


class PrescriptionCreateSerializer(serializers.ModelSerializer):
    """
    Création en une requête: prescription + lignes.
    """

    lignes = LignePrescriptionSerializer(many=True)

    class Meta:
        model = Prescription
        fields = [
            "id",
            "patient",
            "dossier",
            "consultation",
            "praticien",
            "titre",
            "note_praticien",
            "lignes",
        ]

    def create(self, validated_data):
        lignes_data = validated_data.pop("lignes", [])
        prescription = Prescription.objects.create(**validated_data)
        for ligne in lignes_data:
            LignePrescription.objects.create(prescription=prescription, **ligne)
        return prescription


#EbaJioloLewis
