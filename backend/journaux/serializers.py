from rest_framework import serializers

from .models import LogActivite


class LogActiviteSerializer(serializers.ModelSerializer):
    acteur_username = serializers.CharField(source="acteur.username", read_only=True)
    acteur_role = serializers.CharField(source="acteur.role", read_only=True)

    class Meta:
        model = LogActivite
        fields = [
            "id",
            "acteur",
            "acteur_username",
            "acteur_role",
            "action",
            "objet_type",
            "objet_id",
            "message",
            "metadata",
            "cree_le",
        ]
        read_only_fields = fields


#EbaJioloLewis
