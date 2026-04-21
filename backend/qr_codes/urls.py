from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import CarnetQRCodeViewSet

router = DefaultRouter()
router.register(r"carnets", CarnetQRCodeViewSet, basename="carnet-qr")

urlpatterns = [
    path("", include(router.urls)),
]
