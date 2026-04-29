from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    CompteRenduIAViewSet,
    MessageAssistantIAViewSet,
    OCRImportCarnetViewSet,
    RecommandationIAViewSet,
    ocr_carnet,
    recherche,
    suggestions_recherche,
    sync_offline,
    warms_ia_general,
    warms_ia_info,
    warms_general,
    warms_info,
    warms_demo,
)

router = DefaultRouter()
router.register(r"ia/ocr-imports", OCRImportCarnetViewSet, basename="ia-ocr-import")
router.register(r"ia/messages", MessageAssistantIAViewSet, basename="ia-message")
router.register(r"ia/recommandations", RecommandationIAViewSet, basename="ia-recommandation")
router.register(r"ia/comptes-rendus", CompteRenduIAViewSet, basename="ia-compte-rendu")

urlpatterns = [
    path("ia/ocr-carnet/", ocr_carnet, name="ia-ocr-carnet"),
    path("ia/warms-general/", warms_ia_general, name="ia-warms-general"),
    path("ia/warms-info/", warms_ia_info, name="ia-warms-info"),
    path("warms-general/", warms_general, name="warms-general"),
    path("warms-info/", warms_info, name="warms-info"),
    path("warms-demo/", warms_demo, name="warms-demo"),
    path("recherche/globale/", recherche, name="recherche-globale"),
    path("recherche/suggestions/", suggestions_recherche, name="recherche-suggestions"),
    path("offline/sync/", sync_offline, name="offline-sync"),
    path("", include(router.urls)),
]


#EbaJioloLewis
