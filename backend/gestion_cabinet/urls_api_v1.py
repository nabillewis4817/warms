from django.http import JsonResponse
from django.urls import include, path


def healthcheck(_request):
    return JsonResponse({"status": "ok", "service": "warms-backend", "version": "v1"})


urlpatterns = [
    path("health/", healthcheck, name="healthcheck"),
    # Les urls d'apps seront branchées ici au fur et à mesure des besoins.
    # "avis/" doit être résolu avant l'inclusion à préfixe vide de "patients.urls"
    # (qui expose aussi une route "avis/<pk>/" pour un modèle différent) sinon
    # Django capture "avis/avis/" comme la route détail patients avec pk="avis".
    path("avis/", include("avis.urls")),
    path("", include("patients.urls")),
    path("", include("rendez_vous.urls")),
    path("", include("consultations.urls")),
    path("", include("prescriptions.urls")),
    path("", include("messagerie.urls")),
    path("", include("assistant_ia.urls")),
    path("", include("statistiques.urls")),
    path("personnel/", include("personnel.urls")),
    path("qr/", include("qr_codes.urls")),
    path("", include("journaux.urls")),
    # Utilisée par l'app mobile (IAService) pour le chat IA partagé
    # web/mobile, les recherches médicales et les analyses de symptômes.
    # Manquait entièrement ici : toutes les requêtes mobiles vers ces
    # fonctionnalités échouaient en 404.
    path("ia-shared/", include("ia_shared.urls")),
    path("", include("comptes_rendus.urls")),
]
