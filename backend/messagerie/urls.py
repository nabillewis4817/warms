from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import ConversationViewSet, NotificationInterneViewSet, ParticipantConversationViewSet

router = DefaultRouter()
router.register(r"conversations", ConversationViewSet, basename="conversation")
router.register(r"participants-conversation", ParticipantConversationViewSet, basename="participant-conversation")
router.register(r"notifications", NotificationInterneViewSet, basename="notification-interne")

urlpatterns = [
    path("", include(router.urls)),
]


#EbaJioloLewis
