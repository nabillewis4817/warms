from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView

from journaux.utils import journaliser

from .models import PasswordResetToken, Utilisateur
from .permissions import EstChirurgienDentiste, PeutGererComptes
from .serializers import (
    ChangerMotDePasseSerializer,
    ForgotPasswordSerializer,
    PreferencesUtilisateurSerializer,
    RegisterSerializer,
    ResetPasswordSerializer,
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

    @action(
        detail=True,
        methods=["post"],
        url_path="valider",
        permission_classes=[EstChirurgienDentiste],
    )
    def valider(self, request, pk=None):
        user = self.get_object()
        user.valider_par_chirurgien(request.user)
        journaliser(
            acteur=request.user,
            action="user.validated",
            objet_type="Utilisateur",
            objet_id=user.id,
            message=f"Compte validé par chirurgien: {user.username}.",
        )
        return Response(UtilisateurSerializer(user).data)


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


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    return Response(
        {"id": user.id, "username": user.username, "role": user.role},
        status=status.HTTP_201_CREATED,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def forgot_password(request):
    serializer = ForgotPasswordSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    email = serializer.validated_data["email"]
    user = Utilisateur.objects.filter(email=email).first()
    if not user:
        # réponse neutre pour ne pas divulguer les emails existants
        return Response({"detail": "Si le compte existe, un token a été généré."})
    token = PasswordResetToken.generate()
    PasswordResetToken.objects.create(utilisateur=user, token=token)
    # En prod: envoyer par email. En dev, on renvoie le token.
    return Response({"detail": "Token généré.", "token": token})


# Vue personnalisée pour l'authentification mobile des patients
class CustomTokenObtainPairView(TokenObtainPairView):
    """Vue personnalisée pour gérer l'authentification des patients et du personnel"""
    
    def post(self, request, *args, **kwargs):
        try:
            response = super().post(request, *args, **kwargs)

            # Ajouter des informations supplémentaires pour le mobile
            if response.status_code == 200:
                user = request.user
                
                # Vérifier que l'utilisateur est authentifié et a les attributs nécessaires
                if not user or not hasattr(user, 'id'):
                    return Response({
                        'detail': 'Erreur lors de la récupération des informations utilisateur',
                        'error': 'Utilisateur invalide'
                    }, status=500)
                
                response.data.update({
                    'user_id': user.id,
                    'username': user.username,
                    'role': getattr(user, 'role', None),
                    'first_name': getattr(user, 'first_name', ''),
                    'last_name': getattr(user, 'last_name', ''),
                })

                # Si c'est un patient, ajouter les informations du patient
                role = getattr(user, 'role', None)
                if role == 'PATIENT':
                    try:
                        patient = Patient.objects.get(user=user)
                        response.data.update({
                            'patient_id': patient.id,
                            'numero_dossier': getattr(patient, 'numero_dossier', None),
                            'qr_token': getattr(patient, 'qr_token', None),
                        })
                    except Patient.DoesNotExist:
                        # Le patient n'existe pas encore, mais l'utilisateur a le rôle PATIENT
                        response.data.update({
                            'patient_id': None,
                            'message': 'Compte patient créé mais profil incomplet. Contactez l\'administration.'
                        })

            return response

        except Exception as e:
            # Logger l'erreur pour le débogage
            print(f"Erreur d'authentification: {str(e)}")
            return Response({
                'detail': 'Erreur lors de l\'authentification',
                'error': str(e)
            }, status=500)


@api_view(["POST"])
@permission_classes([AllowAny])
def reset_password(request):
    serializer = ResetPasswordSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    token_value = serializer.validated_data["token"]
    nouveau_mot_de_passe = serializer.validated_data["nouveau_mot_de_passe"]

    token = PasswordResetToken.objects.filter(token=token_value, utilise=False).first()
    if not token:
        return Response({"detail": "Token invalide."}, status=status.HTTP_400_BAD_REQUEST)
    user = token.utilisateur
    user.set_password(nouveau_mot_de_passe)
    user.save(update_fields=["password"])
    token.utilise = True
    token.save(update_fields=["utilise"])
    return Response({"detail": "Mot de passe réinitialisé."})


#EbaJioloLewis
