from django.http import JsonResponse
from django.urls import path, include
from rest_framework.routers import DefaultRouter

from ocr.views import extract_text as ocr_extract_text

from . import views

router = DefaultRouter()
router.register(r'conversations', views.ConversationIAViewSet, basename='ia_conversations')
router.register(r'recherches', views.RechercheIAViewSet, basename='ia_recherches')
router.register(r'analyses', views.AnalyseMedicaleViewSet, basename='ia_analyses')
router.register(r'documents', views.DocumentOCRViewSet, basename='ia_documents')


def _healthcheck(_request):
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path('', include(router.urls)),
    path('preferences/', views.preferences_ia, name='ia_preferences'),
    path('statistiques/', views.statistiques_ia, name='ia_statistiques'),
    # Appelée directement par l'app mobile (IAService.traiterImageOCR) :
    # attendait jusqu'ici une route littérale "ocr/extract-text/" qui
    # n'existait nulle part (seul "documents/" — un ViewSet REST différent
    # — était exposé), d'où un 404 systématique côté mobile.
    path('ocr/extract-text/', ocr_extract_text, name='ia_ocr_extract_text'),
    path('health/', _healthcheck, name='ia_health'),
]
