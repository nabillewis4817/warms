from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import DossierPatientViewSet, PageCarnetViewSet, PatientViewSet, PieceJointeDossierViewSet

router = DefaultRouter()
router.register(r"patients", PatientViewSet, basename="patient")
router.register(r"dossiers", DossierPatientViewSet, basename="dossier")
router.register(r"pages", PageCarnetViewSet, basename="page-carnet")
router.register(r"pieces-jointes", PieceJointeDossierViewSet, basename="piece-jointe")

urlpatterns = [
    path("", include(router.urls)),
]
