import re

from rest_framework import serializers

from .models import AvisPatient, DossierPatient, PageCarnet, Patient, PieceJointeDossier


class PatientSerializer(serializers.ModelSerializer):
    numero_dossier = serializers.CharField(source="dossier.numero_dossier", read_only=True)
    qr_token = serializers.CharField(source="dossier.qr.token", read_only=True)
    dossier_id = serializers.CharField(source="dossier.id", read_only=True)
    allergies = serializers.CharField(source="dossier.allergies", read_only=True, default="")

    class Meta:
        model = Patient
        fields = [
            "id",
            "prenom",
            "nom",
            "photo",
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
            "groupe_sanguin",
            "derniere_consultation_date",
            "derniere_consultation_lieu",
            "derniere_consultation_details",
            "infirmiere_referente",
            "numero_dossier",
            "dossier_id",
            "qr_token",
            "allergies",
            "actif",
            "supprime_le",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = ["supprime_le"]

    def validate_telephone(self, value):
        if value:
            cleaned = re.sub(r"[\s\-\(\)]", "", value)
            if not re.match(r"^\+?[0-9]{8,15}$", cleaned):
                raise serializers.ValidationError("Le numéro de téléphone doit contenir entre 8 et 15 chiffres.")
            # Avertissement doublon (non bloquant pour les familles partageant un n°)
            qs = Patient.objects.filter(telephone=value)
            if self.instance:
                qs = qs.exclude(pk=self.instance.pk)
            if qs.exists():
                existing = qs.first()
                raise serializers.ValidationError(
                    f"Ce numéro est déjà utilisé par {existing.prenom} {existing.nom}."
                )
        return value

    def validate_email(self, value):
        if not value:
            return value
        qs = Patient.objects.filter(email=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            existing = qs.first()
            raise serializers.ValidationError(
                f"Cet email est déjà utilisé par {existing.prenom} {existing.nom}."
            )
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
