from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'avis', views.AvisViewSet, basename='avis')
router.register(r'statistiques', views.StatistiquesAvisViewSet, basename='statistiques_avis')
router.register(r'motifs-signalement', views.MotifSignalementViewSet, basename='motifs_signalement')

urlpatterns = [
    path('', include(router.urls)),
]
