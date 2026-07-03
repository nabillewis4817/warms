from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes, parser_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from django.db.models import Q

from journaux.utils import journaliser

from .emails import envoyer_email_compte_cree, envoyer_email_mot_de_passe_modifie
from .models import DemandePersonnel, PasswordResetToken, Utilisateur

# Import pour la gestion des patients dans l'authentification
try:
    from patients.models import Patient
except ImportError:
    Patient = None
from .permissions import EstChirurgienDentiste, PeutGererComptes, PeutVoirJournaux
from .serializers import (
    ChangerMotDePasseSerializer,
    DemandePersonnelSerializer,
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
@permission_classes([IsAuthenticated])
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
            "photo_profil": request.build_absolute_uri(user.photo_profil.url) if getattr(user, "photo_profil", None) else None,
            "langue_interface": getattr(user, "langue_interface", "fr"),
            "mode_sombre": getattr(user, "mode_sombre", False),
            "theme_couleur": getattr(user, "theme_couleur", "bleu"),
            "preferences_notifications": getattr(user, "preferences_notifications", {}),
        }
    )


class UtilisateurViewSet(viewsets.ModelViewSet):
    queryset = Utilisateur.objects.all().order_by("-date_joined")
    permission_classes = [IsAuthenticated]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_queryset(self):
        # Sans ce filtrage, tous les comptes (y compris les patients) sont
        # renvoyés quels que soient les paramètres de requête envoyés par le
        # frontend (ex: le sélecteur de praticien d'une prescription) :
        # les paramètres "role"/"statut" étaient jusqu'ici silencieusement
        # ignorés côté backend.
        queryset = super().get_queryset()
        role = self.request.query_params.get("role")
        if role:
            queryset = queryset.filter(role=role)
        statut = self.request.query_params.get("statut")
        if statut:
            queryset = queryset.filter(statut=statut)
        recherche = self.request.query_params.get("recherche")
        if recherche:
            queryset = queryset.filter(
                Q(first_name__icontains=recherche)
                | Q(last_name__icontains=recherche)
                | Q(username__icontains=recherche)
            )
        return queryset

    def get_permissions(self):
        if self.action in ["create", "update", "partial_update", "destroy", "desactiver", "changer_mot_de_passe"]:
            self.permission_classes = [PeutGererComptes]
        elif self.action in ["valider"]:
            self.permission_classes = [EstChirurgienDentiste]
        else:
            self.permission_classes = [IsAuthenticated]
        return super().get_permissions()

    def list(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)

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
        envoyer_email_compte_cree(
            user,
            mot_de_passe=getattr(user, "mot_de_passe_genere", None),
            en_attente_validation=not user.is_active,
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
        envoyer_email_compte_cree(user)
        return Response(UtilisateurSerializer(user).data)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def me_fcm_token(request):
    """Enregistre/met à jour le jeton FCM de l'appareil mobile courant,
    utilisé pour envoyer de vraies notifications push (voir
    messagerie.services_push)."""
    token = (request.data.get("fcm_token") or "").strip()
    request.user.fcm_token = token
    request.user.save(update_fields=["fcm_token"])
    return Response({"fcm_token": request.user.fcm_token})


@api_view(["PATCH"])
@permission_classes([IsAuthenticated])
@parser_classes([JSONParser, MultiPartParser, FormParser])
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
@permission_classes([IsAuthenticated])
def changer_mon_mot_de_passe(request):
    """Changement de mot de passe en self-service (vérifie l'ancien mot de passe)."""
    from django.contrib.auth.password_validation import validate_password
    from django.core.exceptions import ValidationError as DjangoValidationError

    user = request.user
    ancien = request.data.get("ancien_mot_de_passe", "")
    nouveau = request.data.get("nouveau_mot_de_passe", "")

    if not ancien or not user.check_password(ancien):
        return Response({"detail": "Mot de passe actuel incorrect."}, status=status.HTTP_400_BAD_REQUEST)
    if not nouveau:
        return Response({"detail": "Le nouveau mot de passe est requis."}, status=status.HTTP_400_BAD_REQUEST)
    try:
        validate_password(nouveau, user=user)
    except DjangoValidationError as exc:
        return Response({"detail": " ".join(exc.messages)}, status=status.HTTP_400_BAD_REQUEST)

    user.set_password(nouveau)
    user.save(update_fields=["password"])
    journaliser(
        acteur=user,
        action="user.password_self_changed",
        objet_type="Utilisateur",
        objet_id=user.id,
        message=f"Changement de mot de passe par {user.username} (self-service).",
    )
    return Response({"detail": "Mot de passe modifié avec succès."})


@api_view(["GET"])
@permission_classes([EstChirurgienDentiste])
def exporter_sauvegarde(request):
    """Exporte une sauvegarde JSON complète des données métier du cabinet."""
    from django.apps import apps
    from django.core import serializers as django_serializers
    from django.http import HttpResponse
    from django.utils import timezone

    apps_a_sauvegarder = [
        "personnel", "patients", "rendez_vous", "consultations",
        "messagerie", "journaux", "avis", "prescriptions", "qr_codes",
    ]
    objets = []
    for app_label in apps_a_sauvegarder:
        try:
            config = apps.get_app_config(app_label)
        except LookupError:
            continue
        for model in config.get_models():
            objets.extend(model.objects.all())

    donnees = django_serializers.serialize("json", objets, indent=2)
    horodatage = timezone.now().strftime("%Y%m%d_%H%M%S")
    reponse = HttpResponse(donnees, content_type="application/json")
    reponse["Content-Disposition"] = f'attachment; filename="warms_sauvegarde_{horodatage}.json"'

    journaliser(
        acteur=request.user,
        action="systeme.sauvegarde_exportee",
        objet_type="Sauvegarde",
        objet_id=0,
        message=f"Export d'une sauvegarde complète ({len(objets)} enregistrement(s)).",
    )
    return reponse


@api_view(["POST"])
@permission_classes([EstChirurgienDentiste])
@parser_classes([MultiPartParser, FormParser])
def restaurer_sauvegarde(request):
    """Restaure les données métier à partir d'un fichier de sauvegarde JSON."""
    from django.core import serializers as django_serializers
    from django.db import transaction

    fichier = request.FILES.get("fichier")
    if not fichier:
        return Response({"detail": "Aucun fichier de sauvegarde fourni."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        contenu = fichier.read().decode("utf-8")
        objets = list(django_serializers.deserialize("json", contenu))
    except Exception as exc:
        return Response({"detail": f"Fichier de sauvegarde invalide : {exc}"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        with transaction.atomic():
            for objet in objets:
                objet.save()
    except Exception as exc:
        return Response(
            {"detail": f"Erreur lors de la restauration, aucune modification appliquée : {exc}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    journaliser(
        acteur=request.user,
        action="systeme.sauvegarde_restauree",
        objet_type="Sauvegarde",
        objet_id=0,
        message=f"Restauration d'une sauvegarde ({len(objets)} enregistrement(s)).",
    )
    return Response({"detail": f"{len(objets)} enregistrement(s) restauré(s) avec succès."})


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
                # Récupérer l'utilisateur manuellement depuis les identifiants
                from django.contrib.auth import authenticate
                username = request.data.get('username')
                password = request.data.get('password')
                
                user = authenticate(username=username, password=password)
                
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
                if role == 'patient' and Patient is not None:
                    try:
                        patient = Patient.objects.get(user=user)
                        response.data.update({
                            'patient_id': patient.id,
                            'numero_dossier': getattr(patient, 'numero_dossier', None),
                            'qr_token': getattr(patient, 'qr_token', None),
                        })
                    except Patient.DoesNotExist:
                        # Le patient n'existe pas encore, mais l'utilisateur a le rôle patient
                        response.data.update({
                            'patient_id': None,
                            'message': 'Compte patient créé mais profil incomplet. Contactez l\'administration.'
                        })
                elif role == 'patient' and Patient is None:
                    # Le modèle Patient n'est pas disponible
                    response.data.update({
                        'patient_id': None,
                        'message': 'Module patient non disponible. Contactez l\'administration.'
                    })

                journaliser(
                    acteur=user,
                    action="auth.login",
                    objet_type="Utilisateur",
                    objet_id=user.id,
                    message=f"Connexion réussie ({user.username}).",
                    metadata={"role": getattr(user, "role", None)},
                )

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
    envoyer_email_mot_de_passe_modifie(user)
    return Response({"detail": "Mot de passe réinitialisé."})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def dashboard_stats(request):
    """
    Endpoint pour les statistiques du tableau de bord.
    Retourne des données réelles de PostgreSQL.
    """
    from django.utils import timezone
    from datetime import timedelta
    from django.db.models import Count, Q, Avg
    from decimal import Decimal
    
    # Importer les modèles
    try:
        from consultations.models import Appel, Consultation
        from rendez_vous.models import RendezVous
        from patients.models import Patient
    except ImportError as e:
        return Response({"error": f"Modèle manquant: {e}"}, status=500)
    
    today = timezone.now().date()
    week_start = today - timedelta(days=today.weekday())
    month_start = today.replace(day=1)
    last_month_start = (month_start - timedelta(days=1)).replace(day=1)
    
    # Statistiques des consultations
    consultations_total = Consultation.objects.count()
    consultations_aujourd_hui = Consultation.objects.filter(date__date=today).count()
    consultations_semaine = Consultation.objects.filter(date__date__gte=week_start).count()
    consultations_mois = Consultation.objects.filter(date__date__gte=month_start).count()
    consultations_mois_dernier = Consultation.objects.filter(
        date__date__gte=last_month_start, 
        date__date__lt=month_start
    ).count()
    
    # Calcul tendance consultations
    if consultations_mois_dernier > 0:
        tendance_consultations = round(((consultations_mois - consultations_mois_dernier) / consultations_mois_dernier) * 100, 1)
    else:
        tendance_consultations = None
    
    # Statistiques des rendez-vous
    rendez_vous_total = RendezVous.objects.count()
    rendez_vous_aujourd_hui = RendezVous.objects.filter(debut__date=today).count()
    rendez_vous_semaine = RendezVous.objects.filter(debut__date__gte=week_start).count()
    rendez_vous_mois = RendezVous.objects.filter(debut__date__gte=month_start).count()
    rendez_vous_mois_dernier = RendezVous.objects.filter(
        debut__date__gte=last_month_start, 
        debut__date__lt=month_start
    ).count()
    
    # Statuts des rendez-vous
    rendez_vous_en_attente = RendezVous.objects.filter(statut='programme').count()
    rendez_vous_confirms = RendezVous.objects.filter(statut='confirme').count()
    rendez_vous_annules = RendezVous.objects.filter(statut='annule').count()
    
    # Calcul tendance rendez-vous
    if rendez_vous_mois_dernier > 0:
        tendance_rendez_vous = round(((rendez_vous_mois - rendez_vous_mois_dernier) / rendez_vous_mois_dernier) * 100, 1)
    else:
        tendance_rendez_vous = None
    
    # Statistiques des appels (modèle Appel)
    appels_qs = Appel.objects.all()
    appels_total = appels_qs.count()
    appels_aujourd_hui = appels_qs.filter(date_appel=today).count()
    appels_semaine = appels_qs.filter(date_appel__gte=week_start).count()
    appels_mois = appels_qs.filter(date_appel__gte=month_start).count()
    appels_mois_dernier = appels_qs.filter(
        date_appel__gte=last_month_start,
        date_appel__lt=month_start,
    ).count()

    appels_repondus = appels_qs.filter(statut=Appel.StatutAppel.PRESENT).count()
    appels_non_repondus = appels_qs.filter(
        statut__in=[Appel.StatutAppel.ABSENT_JUSTIFIE, Appel.StatutAppel.ABSENT_NON_JUSTIFIE]
    ).count()
    appels_en_attente = appels_qs.filter(statut=Appel.StatutAppel.EN_ATTENTE).count()
    
    # Calcul tendance appels
    if appels_mois_dernier > 0:
        tendance_appels = round(((appels_mois - appels_mois_dernier) / appels_mois_dernier) * 100, 1)
    else:
        tendance_appels = None
    
    # Taux d'absentéisme (basé sur les rendez-vous)
    total_rendez_vous_effectues = RendezVous.objects.filter(statut='effectue').count()
    total_rendez_vous_absents = RendezVous.objects.filter(statut='absent').count()
    total_rendez_vous_programmes = total_rendez_vous_effectues + total_rendez_vous_absents
    
    if total_rendez_vous_programmes > 0:
        taux_absenteeisme_global = round((total_rendez_vous_absents / total_rendez_vous_programmes) * 100, 1)
    else:
        taux_absenteeisme_global = 0.0
    
    # Taux absentéisme mois
    rdv_effectues_mois = RendezVous.objects.filter(statut='effectue', debut__date__gte=month_start).count()
    rdv_absents_mois = RendezVous.objects.filter(statut='absent', debut__date__gte=month_start).count()
    total_rdv_mois = rdv_effectues_mois + rdv_absents_mois
    
    if total_rdv_mois > 0:
        taux_absenteeisme_mois = round((rdv_absents_mois / total_rdv_mois) * 100, 1)
    else:
        taux_absenteeisme_mois = 0.0
    
    # Taux absentéisme semaine
    rdv_effectues_semaine = RendezVous.objects.filter(statut='effectue', debut__date__gte=week_start).count()
    rdv_absents_semaine = RendezVous.objects.filter(statut='absent', debut__date__gte=week_start).count()
    total_rdv_semaine = rdv_effectues_semaine + rdv_absents_semaine
    
    if total_rdv_semaine > 0:
        taux_absenteeisme_semaine = round((rdv_absents_semaine / total_rdv_semaine) * 100, 1)
    else:
        taux_absenteeisme_semaine = 0.0
    
    # Calcul tendance absentéisme
    rdv_absents_mois_dernier = RendezVous.objects.filter(
        statut='absent', 
        debut__date__gte=last_month_start,
        debut__date__lt=month_start
    ).count()
    total_rdv_mois_dernier = RendezVous.objects.filter(
        debut__date__gte=last_month_start,
        debut__date__lt=month_start,
        statut__in=['effectue', 'absent']
    ).count()
    
    if total_rdv_mois_dernier > 0:
        taux_absenteeisme_mois_dernier = round((rdv_absents_mois_dernier / total_rdv_mois_dernier) * 100, 1)
        tendance_absenteeisme = round(taux_absenteeisme_mois - taux_absenteeisme_mois_dernier, 1)
    else:
        tendance_absenteeisme = None
    
    # Statistiques des patients
    patients_total = Patient.objects.count()
    patients_aujourd_hui = Patient.objects.filter(cree_le__date=today).count()
    patients_semaine = Patient.objects.filter(cree_le__date__gte=week_start).count()
    patients_mois = Patient.objects.filter(cree_le__date__gte=month_start).count()
    patients_mois_dernier = Patient.objects.filter(
        cree_le__date__gte=last_month_start, 
        cree_le__date__lt=month_start
    ).count()
    
    # Calcul tendance patients
    if patients_mois_dernier > 0:
        tendance_patients = round(((patients_mois - patients_mois_dernier) / patients_mois_dernier) * 100, 1)
    else:
        tendance_patients = None
    
    stats = {
        "consultations": {
            "total": consultations_total,
            "aujourdHui": consultations_aujourd_hui,
            "semaine": consultations_semaine,
            "mois": consultations_mois,
            "tendance": tendance_consultations
        },
        "rendezVous": {
            "total": rendez_vous_total,
            "aujourdHui": rendez_vous_aujourd_hui,
            "semaine": rendez_vous_semaine,
            "mois": rendez_vous_mois,
            "tendance": tendance_rendez_vous,
            "enAttente": rendez_vous_en_attente,
            "confirms": rendez_vous_confirms,
            "annules": rendez_vous_annules
        },
        "appels": {
            "total": appels_total,
            "aujourdHui": appels_aujourd_hui,
            "semaine": appels_semaine,
            "mois": appels_mois,
            "tendance": tendance_appels,
            "repondus": appels_repondus,
            "nonRepondus": appels_non_repondus,
            "enAttente": appels_en_attente
        },
        "tauxAbsenteeisme": {
            "global": taux_absenteeisme_global,
            "mois": taux_absenteeisme_mois,
            "semaine": taux_absenteeisme_semaine,
            "tendance": tendance_absenteeisme,
            "absences": total_rendez_vous_absents,
            "presences": total_rendez_vous_effectues
        },
        "patients": {
            "total": patients_total,
            "aujourdHui": patients_aujourd_hui,
            "semaine": patients_semaine,
            "mois": patients_mois,
            "tendance": tendance_patients
        }
    }
    
    return Response(stats)


# Endpoints pour les services
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def services_list(request):
    """Retourne la liste des services disponibles"""
    print(f"DEBUG: Services - User: {request.user}")
    print(f"DEBUG: Services - Is authenticated: {request.user.is_authenticated if hasattr(request.user, 'is_authenticated') else 'No user'}")
    
    services = [
        {"id": 1, "nom": "Consultation", "description": "Services de consultation dentaire"},
        {"id": 2, "nom": "Chirurgie", "description": "Services chirurgicaux"},
        {"id": 3, "nom": "Orthodontie", "description": "Services orthodontiques"},
        {"id": 4, "nom": "Urgence", "description": "Services d'urgence dentaire"},
    ]
    return Response(services)


# Endpoints pour les rôles
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def roles_list(request):
    """Retourne la liste des rôles disponibles"""
    print(f"DEBUG: Rôles - User: {request.user}")
    print(f"DEBUG: Rôles - Is authenticated: {request.user.is_authenticated if hasattr(request.user, 'is_authenticated') else 'No user'}")
    
    roles = [
        {"id": "chirurgien_dentiste", "nom": "Chirurgien-Dentiste", "description": "Médecin dentiste"},
        {"id": "secretaire", "nom": "Secrétaire", "description": "Personnel administratif"},
        {"id": "infirmiere", "nom": "Infirmière", "description": "Personnel infirmier"},
        {"id": "assistant", "nom": "Assistant", "description": "Assistant dentaire"},
        {"id": "admin", "nom": "Administrateur", "description": "Administration générale"},
    ]
    return Response(roles)


# Endpoints pour les spécialités
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def specialites_list(request):
    """Retourne la liste des spécialités disponibles"""
    print(f"DEBUG: Spécialités - User: {request.user}")
    print(f"DEBUG: Spécialités - Is authenticated: {request.user.is_authenticated if hasattr(request.user, 'is_authenticated') else 'No user'}")
    
    specialites = [
        {"id": 1, "nom": "Odontologie générale", "description": "Soins dentaires généraux"},
        {"id": 2, "nom": "Chirurgie orale", "description": "Chirurgie de la bouche"},
        {"id": 3, "nom": "Orthodontie", "description": "Correction des alignements"},
        {"id": 4, "nom": "Parodontologie", "description": "Soins des gencives"},
        {"id": 5, "nom": "Pédiatrie", "description": "Dentisterie pour enfants"},
    ]
    return Response(specialites)


# Endpoints pour les journaux
@api_view(["GET"])
@permission_classes([PeutVoirJournaux])
def journaux_list(request):
    """Retourne la liste des journaux d'activité"""
    try:
        from journaux.models import LogActivite
        from django.utils import timezone
        from datetime import timedelta
        
        # Paramètres de filtrage
        recherche = request.GET.get('recherche', '')
        type_filter = request.GET.get('type', '')
        utilisateur_filter = request.GET.get('utilisateur', '')
        date_debut = request.GET.get('dateDebut', '')
        date_fin = request.GET.get('dateFin', '')
        
        # Base queryset
        queryset = LogActivite.objects.all().order_by('-cree_le')
        
        # Filtrage
        if recherche:
            queryset = queryset.filter(
                Q(action__icontains=recherche) |
                Q(details__icontains=recherche) |
                Q(acteur__username__icontains=recherche) |
                Q(acteur__first_name__icontains=recherche) |
                Q(acteur__last_name__icontains=recherche)
            )
        
        if type_filter:
            queryset = queryset.filter(type_action=type_filter)
        
        if utilisateur_filter:
            queryset = queryset.filter(acteur__username__icontains=utilisateur_filter)
        
        if date_debut:
            queryset = queryset.filter(cree_le__date__gte=date_debut)
        
        if date_fin:
            queryset = queryset.filter(cree_le__date__lte=date_fin)
        
        # Sérialisation
        journaux = []
        for log in queryset[:200]:
            acteur_label = "Système"
            if log.acteur:
                nom = f"{log.acteur.first_name} {log.acteur.last_name}".strip()
                acteur_label = nom or log.acteur.username
            journaux.append({
                "id": log.id,
                "date": log.cree_le.strftime('%Y-%m-%d %H:%M'),
                "utilisateur": acteur_label,
                "action": log.action.replace('.', ' ').replace('_', ' ').title(),
                "details": log.details or log.action,
                "type": log.type_action or get_journal_type(log.action),
                "icone": get_journal_icon(log.action)
            })
        
        return Response(journaux)
        
    except ImportError:
        # Si le modèle LogActivite n'existe pas, retourner des données de test
        journaux_test = [
            {
                "id": 1,
                "date": "2026-05-04 10:30",
                "utilisateur": "Secrétaire",
                "action": "Création Infirmière",
                "details": "Création du compte pour l'infirmière",
                "type": "personnel",
                "icone": "person_add"
            },
            {
                "id": 2,
                "date": "2026-05-04 10:25",
                "utilisateur": "Dr. Martin",
                "action": "Connexion",
                "details": "Connexion au système",
                "type": "systeme",
                "icone": "login"
            }
        ]
        return Response(journaux_test)
    except Exception as e:
        return Response({"error": str(e)}, status=500)


@api_view(["GET"])
@permission_classes([PeutVoirJournaux])
def journaux_types(request):
    """Retourne les types de journaux disponibles"""
    types = ["patient", "consultation", "rendez_vous", "systeme", "personnel"]
    return Response(types)


@api_view(["GET"])
@permission_classes([PeutVoirJournaux])
def journaux_utilisateurs(request):
    """Retourne les utilisateurs disponibles pour les filtres"""
    try:
        utilisateurs = Utilisateur.objects.all().values_list('username', flat=True)
        return Response(list(utilisateurs))
    except Exception as e:
        return Response(["Dr. Martin", "Secrétaire", "Dr. Dubois"])


@api_view(["GET"])
@permission_classes([PeutVoirJournaux])
def journaux_export(request):
    """Exporte les journaux en CSV"""
    try:
        import csv
        from django.http import HttpResponse
        
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="journaux.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['ID', 'Date', 'Utilisateur', 'Action', 'Détails', 'Type'])
        
        # Données de test pour l'export
        writer.writerow([1, '2026-05-04 10:30', 'Secrétaire', 'Création Infirmière', 'Création du compte pour l\'infirmière', 'personnel'])
        writer.writerow([2, '2026-05-04 10:25', 'Dr. Martin', 'Connexion', 'Connexion au système', 'systeme'])
        
        return response
        
    except Exception as e:
        return Response({"error": str(e)}, status=500)


def get_journal_type(action):
    """Détermine le type de journal basé sur l'action"""
    action_lower = action.lower()
    if 'patient' in action_lower:
        return 'patient'
    elif 'consultation' in action_lower:
        return 'consultation'
    elif 'rendez' in action_lower or 'appointment' in action_lower:
        return 'rendez_vous'
    elif 'user' in action_lower or 'personnel' in action_lower:
        return 'personnel'
    else:
        return 'systeme'


def get_journal_icon(action):
    """Détermine l'icône basée sur l'action"""
    action_lower = action.lower()
    if 'created' in action_lower or 'creation' in action_lower:
        return 'bi-person-plus'
    elif 'updated' in action_lower or 'modification' in action_lower:
        return 'bi-pencil'
    elif 'deleted' in action_lower or 'suppression' in action_lower:
        return 'bi-trash'
    elif 'login' in action_lower or 'connexion' in action_lower:
        return 'bi-box-arrow-in-right'
    elif 'consultation' in action_lower:
        return 'bi-clipboard2'
    elif 'rendez' in action_lower or 'appointment' in action_lower:
        return 'bi-calendar-check'
    else:
        return 'bi-circle'


class DemandePersonnelViewSet(viewsets.ModelViewSet):
    """
    Demandes de création de comptes soumises par la secrétaire, validées par le chirurgien.
    POST (secrétaire) → statut='en_attente'
    PATCH /{id}/ (chirurgien) → statut='approuvee' | 'rejetee'
    """
    serializer_class = DemandePersonnelSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if getattr(user, 'role', None) == Utilisateur.Role.SECRETAIRE:
            return DemandePersonnel.objects.filter(soumis_par=user)
        return DemandePersonnel.objects.all()

    def perform_create(self, serializer):
        serializer.save(soumis_par=self.request.user)

    @action(detail=True, methods=['patch'], url_path='valider')
    def valider(self, request, pk=None):
        from django.utils import timezone
        demande = self.get_object()
        nouveau_statut = request.data.get('statut')
        if nouveau_statut not in ('approuvee', 'rejetee'):
            return Response({'detail': "statut doit être 'approuvee' ou 'rejetee'"}, status=status.HTTP_400_BAD_REQUEST)

        if nouveau_statut == 'approuvee' and demande.statut != 'approuvee':
            if Utilisateur.objects.filter(username=demande.username).exists():
                return Response(
                    {'detail': f"Le nom d'utilisateur '{demande.username}' est déjà utilisé."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            compte = Utilisateur.objects.create_user(
                username=demande.username,
                password=demande.mot_de_passe_temporaire,
                role=demande.role,
                first_name=demande.prenom,
                last_name=demande.nom,
                email=demande.email,
                telephone=demande.telephone,
                service=demande.service,
                specialite=demande.specialite,
            )
            envoyer_email_compte_cree(compte, mot_de_passe=demande.mot_de_passe_temporaire)

        demande.statut = nouveau_statut
        demande.traite_le = timezone.now()
        demande.note_traitement = request.data.get('note', '')
        demande.save()
        return Response(DemandePersonnelSerializer(demande).data)


#EbaJioloLewis
