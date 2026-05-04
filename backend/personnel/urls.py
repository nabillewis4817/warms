from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    UtilisateurViewSet,
    CustomTokenObtainPairView,
    dashboard_stats,
    forgot_password,
    me,
    me_preferences,
    ping,
    register,
    reset_password,
    services_list,
    roles_list,
    specialites_list,
    journaux_list,
    journaux_types,
    journaux_utilisateurs,
    journaux_export,
)

router = DefaultRouter()
router.register(r"personnel", UtilisateurViewSet, basename="personnel")

urlpatterns = [
    path("ping/", ping, name="personnel-ping"),
    # Dashboard
    path("dashboard/stats/", dashboard_stats, name="dashboard-stats"),
    # Auth JWT
    path("auth/token/", CustomTokenObtainPairView.as_view(), name="token-obtain-pair"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/register/", register, name="register"),
    path("auth/forgot-password/", forgot_password, name="forgot-password"),
    path("auth/reset-password/", reset_password, name="reset-password"),
    # Profil utilisateur
    path("me/", me, name="me"),
    path("me/preferences/", me_preferences, name="me-preferences"),
    # Données de référence
    path("services/", services_list, name="services-list"),
    path("roles/", roles_list, name="roles-list"),
    path("specialites/", specialites_list, name="specialites-list"),
    # Journaux
    path("journaux/", journaux_list, name="journaux-list"),
    path("journaux/types/", journaux_types, name="journaux-types"),
    path("journaux/utilisateurs/", journaux_utilisateurs, name="journaux-utilisateurs"),
    path("journaux/export/", journaux_export, name="journaux-export"),
    path("", include(router.urls)),
]


#EbaJioloLewis
