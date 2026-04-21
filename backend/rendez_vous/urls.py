from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import RendezVousViewSet

router = DefaultRouter()
router.register(r"rendez-vous", RendezVousViewSet, basename="rendez-vous")

urlpatterns = [
    path("", include(router.urls)),
]


#EbaJioloLewis
