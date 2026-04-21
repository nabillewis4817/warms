from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    CompteRenduIAViewSet,
    MessageAssistantIAViewSet,
    OCRImportCarnetViewSet,
    RecommandationIAViewSet,
    recherche,
    suggestions_recherche,
    sync_offline,
)

router = DefaultRouter()
router.register(r"ia/ocr-imports", OCRImportCarnetViewSet, basename="ia-ocr-import")
router.register(r"ia/messages", MessageAssistantIAViewSet, basename="ia-message")
router.register(r"ia/recommandations", RecommandationIAViewSet, basename="ia-recommandation")
router.register(r"ia/comptes-rendus", CompteRenduIAViewSet, basename="ia-compte-rendu")

urlpatterns = [
    path("recherche/globale/", recherche, name="recherche-globale"),
    path("recherche/suggestions/", suggestions_recherche, name="recherche-suggestions"),
    path("offline/sync/", sync_offline, name="offline-sync"),
    path("", include(router.urls)),
]


#EbaJioloLewis
