from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    ActeRealiseViewSet,
    AppelViewSet,
    ConsultationViewSet,
    PhotoCliniqueViewSet,
    SchemaDentaireViewSet,
    SuiviDouleurViewSet,
    TauxAbsenteismeViewSet,
)

router = DefaultRouter()
router.register(r"consultations", ConsultationViewSet, basename="consultation")
router.register(r"actes", ActeRealiseViewSet, basename="acte-realise")
router.register(r"schemas-dentaires", SchemaDentaireViewSet, basename="schema-dentaire")
router.register(r"photos-cliniques", PhotoCliniqueViewSet, basename="photo-clinique")
router.register(r"appels", AppelViewSet, basename="appel")
router.register(r"taux-absenteisme", TauxAbsenteismeViewSet, basename="taux-absenteisme")
router.register(r'suivis-douleur', SuiviDouleurViewSet, basename='suivis-douleur')

urlpatterns = [
    path("", include(router.urls)),
]


#EbaJioloLewis
