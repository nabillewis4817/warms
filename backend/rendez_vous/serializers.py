from rest_framework import serializers

from .models import RendezVous


class RendezVousSerializer(serializers.ModelSerializer):
    patient_nom = serializers.CharField(source="patient.nom", read_only=True)
    patient_prenom = serializers.CharField(source="patient.prenom", read_only=True)
    praticien_nom = serializers.SerializerMethodField()
    praticien_prenom = serializers.SerializerMethodField()

    class Meta:
        model = RendezVous
        fields = [
            "id",
            "patient",
            "patient_prenom",
            "patient_nom",
            "praticien",
            "praticien_nom",
            "praticien_prenom",
            "infirmiere",
            "debut",
            "fin",
            "motif",
            "notes",
            "statut",
            "motif_absence",
            "raison_annulation",
            "cree_par",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = ["cree_par", "cree_le", "modifie_le"]

    def get_praticien_nom(self, obj):
        return obj.praticien.last_name if obj.praticien else ""

    def get_praticien_prenom(self, obj):
        return obj.praticien.first_name if obj.praticien else ""

    def validate(self, attrs):
        debut = attrs.get("debut") or getattr(self.instance, "debut", None)
        fin = attrs.get("fin") or getattr(self.instance, "fin", None)
        if debut and fin and fin <= debut:
            raise serializers.ValidationError("La fin doit être après le début.")
        return attrs


#EbaJioloLewis
