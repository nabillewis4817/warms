from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import LignePrescriptionViewSet, PrescriptionViewSet

router = DefaultRouter()
router.register(r"prescriptions", PrescriptionViewSet, basename="prescription")
router.register(r"lignes-prescription", LignePrescriptionViewSet, basename="ligne-prescription")

urlpatterns = [
    path("", include(router.urls)),
]


#EbaJioloLewis
