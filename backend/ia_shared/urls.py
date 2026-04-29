from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'conversations', views.ConversationIAViewSet, basename='ia_conversations')
router.register(r'recherches', views.RechercheIAViewSet, basename='ia_recherches')
router.register(r'analyses', views.AnalyseMedicaleViewSet, basename='ia_analyses')
router.register(r'documents', views.DocumentOCRViewSet, basename='ia_documents')

urlpatterns = [
    path('', include(router.urls)),
    path('preferences/', views.preferences_ia, name='ia_preferences'),
    path('statistiques/', views.statistiques_ia, name='ia_statistiques'),
]
