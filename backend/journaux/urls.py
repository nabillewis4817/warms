from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import LogActiviteViewSet

router = DefaultRouter()
router.register(r"journaux", LogActiviteViewSet, basename="journal")

urlpatterns = [
    path("", include(router.urls)),
]


#EbaJioloLewis
