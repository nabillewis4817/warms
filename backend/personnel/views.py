from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from journaux.utils import journaliser

from .models import Utilisateur
from .permissions import PeutGererComptes
from .serializers import (
    ChangerMotDePasseSerializer,
    PreferencesUtilisateurSerializer,
    UtilisateurCreateSerializer,
    UtilisateurSerializer,
)

@api_view(["GET"])
@permission_classes([AllowAny])
def ping(_request):
    return Response({"module": "personnel", "status": "ok"})


@api_view(["GET"])
def me(request):
    user = request.user
    return Response(
        {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "prenom": user.first_name,
            "nom": user.last_name,
            "role": getattr(user, "role", None),
            "telephone": getattr(user, "telephone", ""),
            "photo_profil": user.photo_profil.url if getattr(user, "photo_profil", None) else None,
            "langue_interface": getattr(user, "langue_interface", "fr"),
            "mode_sombre": getattr(user, "mode_sombre", False),
            "preferences_notifications": getattr(user, "preferences_notifications", {}),
        }
    )


class UtilisateurViewSet(viewsets.ModelViewSet):
    queryset = Utilisateur.objects.all().order_by("-date_joined")
    permission_classes = [PeutGererComptes]
    parser_classes = [MultiPartParser, FormParser]

    def get_serializer_class(self):
        if self.action == "create":
            return UtilisateurCreateSerializer
        return UtilisateurSerializer

    def perform_create(self, serializer):
        user = serializer.save()
        journaliser(
            acteur=self.request.user,
            action="user.created",
            objet_type="Utilisateur",
            objet_id=user.id,
            message=f"Création du compte {user.username} ({user.role}).",
        )

    @action(detail=True, methods=["post"])
    def desactiver(self, request, pk=None):
        user = self.get_object()
        user.is_active = False
        user.save(update_fields=["is_active"])
        journaliser(
            acteur=request.user,
            action="user.deactivated",
            objet_type="Utilisateur",
            objet_id=user.id,
            message=f"Désactivation du compte {user.username}.",
        )
        return Response(UtilisateurSerializer(user).data)

    @action(detail=True, methods=["post"], url_path="changer-mot-de-passe")
    def changer_mot_de_passe(self, request, pk=None):
        user = self.get_object()
        serializer = ChangerMotDePasseSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user.set_password(serializer.validated_data["nouveau_mot_de_passe"])
        user.save(update_fields=["password"])
        journaliser(
            acteur=request.user,
            action="user.password_changed",
            objet_type="Utilisateur",
            objet_id=user.id,
            message=f"Changement de mot de passe pour {user.username}.",
        )
        return Response({"status": "ok"}, status=status.HTTP_200_OK)


@api_view(["PATCH"])
def me_preferences(request):
    user = request.user
    serializer = PreferencesUtilisateurSerializer(user, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save()
    journaliser(
        acteur=request.user,
        action="user.preferences_updated",
        objet_type="Utilisateur",
        objet_id=user.id,
        message="Mise à jour des préférences utilisateur.",
    )
    return Response(serializer.data)


#EbaJioloLewis
