from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import Utilisateur


class UtilisateurSerializer(serializers.ModelSerializer):
    class Meta:
        model = Utilisateur
        fields = [
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "telephone",
            "photo_profil",
            "role",
            "langue_interface",
            "mode_sombre",
            "preferences_notifications",
            "is_active",
            "date_joined",
        ]
        read_only_fields = ["date_joined"]


class UtilisateurCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = Utilisateur
        fields = [
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "telephone",
            "role",
            "password",
        ]

    def validate_password(self, value: str):
        validate_password(value)
        return value

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = Utilisateur(**validated_data)
        user.set_password(password)

        # Convention: tout sauf patient est considéré comme "staff" côté admin Django
        if user.role != Utilisateur.Role.PATIENT:
            user.is_staff = True

        user.save()
        return user


class ChangerMotDePasseSerializer(serializers.Serializer):
    nouveau_mot_de_passe = serializers.CharField(write_only=True)

    def validate_nouveau_mot_de_passe(self, value: str):
        validate_password(value)
        return value


class PreferencesUtilisateurSerializer(serializers.ModelSerializer):
    class Meta:
        model = Utilisateur
        fields = [
            "langue_interface",
            "mode_sombre",
            "preferences_notifications",
            "telephone",
            "photo_profil",
            "first_name",
            "last_name",
            "email",
        ]


#EbaJioloLewis


#EbaJioloLewis
