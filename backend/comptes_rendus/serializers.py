from rest_framework import serializers
from .models import CompteRendu


class CompteRenduSerializer(serializers.ModelSerializer):
    patient_nom    = serializers.CharField(source="patient.nom",    read_only=True)
    patient_prenom = serializers.CharField(source="patient.prenom", read_only=True)
    praticien_nom  = serializers.SerializerMethodField()

    class Meta:
        model  = CompteRendu
        fields = [
            "id", "patient", "patient_nom", "patient_prenom",
            "praticien", "praticien_nom",
            "type_action", "reference_id",
            "titre", "contenu", "contenu_ia_brut", "genere_par_ia",
            "cree_le", "modifie_le",
        ]
        read_only_fields = ["cree_le", "modifie_le", "contenu_ia_brut"]

    def get_praticien_nom(self, obj):
        if obj.praticien:
            return f"Dr. {obj.praticien.first_name} {obj.praticien.last_name}".strip()
        return ""


#EbaJioloLewis
