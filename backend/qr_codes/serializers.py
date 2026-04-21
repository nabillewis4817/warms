from rest_framework import serializers

from .models import CarnetQRCode


class CarnetQRCodeSerializer(serializers.ModelSerializer):
    class Meta:
        model = CarnetQRCode
        fields = ["id", "dossier", "token", "actif", "cree_le"]
        read_only_fields = ["token", "cree_le"]


class VerifierCarnetQRSerializer(serializers.Serializer):
    token = serializers.CharField()
