from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    ActeRealiseViewSet,
    ConsultationViewSet,
    PhotoCliniqueViewSet,
    SchemaDentaireViewSet,
)

router = DefaultRouter()
router.register(r"consultations", ConsultationViewSet, basename="consultation")
router.register(r"actes", ActeRealiseViewSet, basename="acte-realise")
router.register(r"schemas-dentaires", SchemaDentaireViewSet, basename="schema-dentaire")
router.register(r"photos-cliniques", PhotoCliniqueViewSet, basename="photo-clinique")

urlpatterns = [
    path("", include(router.urls)),
]


#EbaJioloLewis
