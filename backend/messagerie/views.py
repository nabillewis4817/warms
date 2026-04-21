from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from journaux.utils import journaliser

from .models import Conversation, Message, NotificationInterne, ParticipantConversation
from .serializers import (
    ConversationSerializer,
    MessageSerializer,
    NotificationInterneSerializer,
    ParticipantConversationSerializer,
)


class ConversationViewSet(viewsets.ModelViewSet):
    queryset = Conversation.objects.prefetch_related("participants").all()
    serializer_class = ConversationSerializer

    def perform_create(self, serializer):
        conversation = serializer.save(cree_par=self.request.user)
        ParticipantConversation.objects.get_or_create(
            conversation=conversation,
            utilisateur=self.request.user,
            defaults={"est_admin": True},
        )
        journaliser(
            acteur=self.request.user,
            action="conversation.created",
            objet_type="Conversation",
            objet_id=conversation.id,
            message=f"Conversation créée: {conversation.titre or conversation.id}",
        )

    @action(detail=True, methods=["post"])
    def ajouter_participant(self, request, pk=None):
        conversation = self.get_object()
        utilisateur_id = request.data.get("utilisateur_id")
        participant, created = ParticipantConversation.objects.get_or_create(
            conversation=conversation,
            utilisateur_id=utilisateur_id,
        )
        if not created:
            return Response({"detail": "Participant déjà présent."}, status=status.HTTP_200_OK)
        NotificationInterne.objects.create(
            destinataire=participant.utilisateur,
            titre="Nouvelle conversation",
            contenu=f"Vous avez été ajouté à la conversation {conversation.id}.",
        )
        return Response({"status": "ok"}, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=["get"])
    def messages(self, request, pk=None):
        conversation = self.get_object()
        qs = Message.objects.filter(conversation=conversation).select_related("auteur")
        return Response(MessageSerializer(qs, many=True).data)

    @action(detail=True, methods=["post"])
    def envoyer_message(self, request, pk=None):
        conversation = self.get_object()
        serializer = MessageSerializer(data={"conversation": conversation.id, "contenu": request.data.get("contenu", "")})
        serializer.is_valid(raise_exception=True)
        message = Message.objects.create(
            conversation=conversation,
            auteur=request.user,
            contenu=serializer.validated_data["contenu"],
        )
        conversation.save(update_fields=["modifie_le"])

        # Notifier les autres participants
        destinataires = conversation.participants.exclude(id=request.user.id)
        NotificationInterne.objects.bulk_create(
            [
                NotificationInterne(
                    destinataire=user,
                    titre="Nouveau message",
                    contenu=f"Nouveau message dans la conversation {conversation.id}.",
                )
                for user in destinataires
            ]
        )
        return Response(MessageSerializer(message).data, status=status.HTTP_201_CREATED)


class ParticipantConversationViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    queryset = ParticipantConversation.objects.select_related("utilisateur", "conversation").all()
    serializer_class = ParticipantConversationSerializer


class NotificationInterneViewSet(
    mixins.ListModelMixin, mixins.UpdateModelMixin, viewsets.GenericViewSet
):
    serializer_class = NotificationInterneSerializer

    def get_queryset(self):
        return NotificationInterne.objects.filter(destinataire=self.request.user)

    @action(detail=True, methods=["post"])
    def marquer_lu(self, request, pk=None):
        notif = self.get_object()
        notif.lu = True
        notif.save(update_fields=["lu"])
        return Response(NotificationInterneSerializer(notif).data)


#EbaJioloLewis
