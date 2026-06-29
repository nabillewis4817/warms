from rest_framework import serializers

from patients.models import DossierPatient

from .models import LignePrescription, Prescription


class LignePrescriptionSerializer(serializers.ModelSerializer):
    # Optionnel : lors d'une création imbriquée (PrescriptionCreateSerializer),
    # la prescription n'existe pas encore au moment où les lignes sont
    # validées — elle n'est associée qu'après coup dans le create()/update()
    # du parent. Sans ce required=False, DRF rejette systématiquement toute
    # prescription créée avec au moins une ligne ("Ce champ est obligatoire").
    prescription = serializers.PrimaryKeyRelatedField(queryset=Prescription.objects.all(), required=False)

    class Meta:
        model = LignePrescription
        fields = ["id", "prescription", "medicament", "posologie", "duree", "remarques"]


class PrescriptionSerializer(serializers.ModelSerializer):
    lignes = LignePrescriptionSerializer(many=True, read_only=True)
    patient_nom = serializers.CharField(source="patient.nom", read_only=True)
    patient_prenom = serializers.CharField(source="patient.prenom", read_only=True)
    praticien_nom = serializers.SerializerMethodField()

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
            "praticien_nom",
            "titre",
            "note_praticien",
            "conseils",
            "recommandations",
            "statut",
            "lignes",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = ["cree_le", "modifie_le"]

    def get_praticien_nom(self, obj):
        if not obj.praticien:
            return ""
        return f"{obj.praticien.first_name} {obj.praticien.last_name}".strip() or obj.praticien.username


class PrescriptionCreateSerializer(serializers.ModelSerializer):
    """
    Création en une requête: prescription + lignes.
    """

    lignes = LignePrescriptionSerializer(many=True, required=False)
    dossier = serializers.PrimaryKeyRelatedField(queryset=DossierPatient.objects.all(), required=False)

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
            "conseils",
            "recommandations",
            "statut",
            "lignes",
        ]

    def create(self, validated_data):
        lignes_data = validated_data.pop("lignes", [])
        prescription = Prescription.objects.create(**validated_data)
        for ligne in lignes_data:
            LignePrescription.objects.create(prescription=prescription, **ligne)
        return prescription

    def update(self, instance, validated_data):
        lignes_data = validated_data.pop("lignes", None)
        for champ, valeur in validated_data.items():
            setattr(instance, champ, valeur)
        instance.save()
        if lignes_data is not None:
            instance.lignes.all().delete()
            for ligne in lignes_data:
                LignePrescription.objects.create(prescription=instance, **ligne)
        return instance


#EbaJioloLewis
