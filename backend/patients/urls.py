from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    AvisPatientViewSet,
    DossierPatientViewSet,
    PageCarnetViewSet,
    PatientViewSet,
    PieceJointeDossierViewSet,
    supprimer_patient_ameliore,
)

router = DefaultRouter()
router.register(r"patients", PatientViewSet, basename="patient")
router.register(r"dossiers", DossierPatientViewSet, basename="dossier")
router.register(r"pages", PageCarnetViewSet, basename="page-carnet")
router.register(r"pieces-jointes", PieceJointeDossierViewSet, basename="piece-jointe")
router.register(r"avis", AvisPatientViewSet, basename="avis-patient")

urlpatterns = [
    path("patients/<int:pk>/supprimer-ameliore/", supprimer_patient_ameliore, name="supprimer-patient-ameliore"),
    path("", include(router.urls)),
]
