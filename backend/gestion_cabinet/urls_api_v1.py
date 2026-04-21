from django.http import JsonResponse
from django.urls import include, path


def healthcheck(_request):
    return JsonResponse({"status": "ok", "service": "warms-backend", "version": "v1"})


urlpatterns = [
    path("health/", healthcheck, name="healthcheck"),
    # Les urls d'apps seront branchées ici au fur et à mesure des besoins.
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
]
