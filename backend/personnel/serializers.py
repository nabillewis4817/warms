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
            "service",
            "specialite",
            "date_embauche",
            "statut",
            "langue_interface",
            "mode_sombre",
            "theme_couleur",
            "preferences_notifications",
            "est_valide_par_chirurgien",
            "valide_par",
            "valide_le",
            "is_active",
            "date_joined",
        ]
        read_only_fields = ["date_joined"]


class UtilisateurCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=False, allow_blank=True)

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
            "service",
            "specialite",
            "date_embauche",
            "statut",
            "photo_profil",
            "password",
        ]

    def validate_password(self, value: str):
        if value:
            validate_password(value)
        return value

    def create(self, validated_data):
        password = validated_data.pop("password", "")
        if not password:
            # Mot de passe temporaire généré si non fourni par l'UI.
            password = Utilisateur.objects.make_random_password(
                length=10,
                allowed_chars="abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789@#",
            )
        user = Utilisateur(**validated_data)
        user.set_password(password)

        request = self.context.get("request")
        createur = request.user if request and request.user.is_authenticated else None

        # Convention: tout sauf patient est considéré comme "staff" côté admin Django
        if user.role != Utilisateur.Role.PATIENT:
            user.is_staff = True

        # Règle métier:
        # - un personnel créé par secrétaire doit être validé par chirurgien
        if (
            createur
            and getattr(createur, "role", None) == Utilisateur.Role.SECRETAIRE
            and user.role in {Utilisateur.Role.INFIRMIERE, Utilisateur.Role.SECRETAIRE}
        ):
            user.est_valide_par_chirurgien = False
            user.is_active = False
        else:
            user.est_valide_par_chirurgien = True

        user.save()
        return user


class ChangerMotDePasseSerializer(serializers.Serializer):
    nouveau_mot_de_passe = serializers.CharField(write_only=True)

    def validate_nouveau_mot_de_passe(self, value: str):
        validate_password(value)
        return value


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = Utilisateur
        fields = [
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
        if user.role != Utilisateur.Role.PATIENT:
            user.is_staff = True
        user.save()
        return user


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ResetPasswordSerializer(serializers.Serializer):
    token = serializers.CharField()
    nouveau_mot_de_passe = serializers.CharField()

    def validate_nouveau_mot_de_passe(self, value: str):
        validate_password(value)
        return value


class PreferencesUtilisateurSerializer(serializers.ModelSerializer):
    class Meta:
        model = Utilisateur
        fields = [
            "langue_interface",
            "mode_sombre",
            "theme_couleur",
            "preferences_notifications",
            "telephone",
            "photo_profil",
            "first_name",
            "last_name",
            "email",
        ]


#EbaJioloLewis


#EbaJioloLewis
