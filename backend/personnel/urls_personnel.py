from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views_personnel

router = DefaultRouter()
router.register(r'personnel', views_personnel.PersonnelViewSet, basename='personnel')
router.register(r'historique-statuts', views_personnel.HistoriqueStatutViewSet, basename='historique-statuts')
router.register(r'presences', views_personnel.PresenceViewSet, basename='presences')

urlpatterns = [
    path('', include(router.urls)),
]
