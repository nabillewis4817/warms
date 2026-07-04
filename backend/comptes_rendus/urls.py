from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import CompteRenduViewSet

router = DefaultRouter()
router.register(r"comptes-rendus", CompteRenduViewSet, basename="compte-rendu")

urlpatterns = [
    path("", include(router.urls)),
]

#EbaJioloLewis
