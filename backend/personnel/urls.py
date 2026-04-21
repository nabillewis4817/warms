from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import UtilisateurViewSet, me, me_preferences, ping

router = DefaultRouter()
router.register(r"utilisateurs", UtilisateurViewSet, basename="utilisateur")

urlpatterns = [
    path("ping/", ping, name="personnel-ping"),
    # Auth JWT
    path("auth/token/", TokenObtainPairView.as_view(), name="token-obtain-pair"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    # Profil utilisateur
    path("me/", me, name="me"),
    path("me/preferences/", me_preferences, name="me-preferences"),
    path("", include(router.urls)),
]


#EbaJioloLewis
