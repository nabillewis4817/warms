from rest_framework import serializers

from .models import Conversation, Message, NotificationInterne, ParticipantConversation


class ParticipantConversationSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="utilisateur.username", read_only=True)
    role = serializers.CharField(source="utilisateur.role", read_only=True)

    class Meta:
        model = ParticipantConversation
        fields = [
            "id",
            "conversation",
            "utilisateur",
            "username",
            "role",
            "est_admin",
            "a_mute",
            "rejoint_le",
        ]


class MessageSerializer(serializers.ModelSerializer):
    auteur_username = serializers.CharField(source="auteur.username", read_only=True)
    envoyeur = serializers.SerializerMethodField()
    timestamp = serializers.DateTimeField(source="cree_le", read_only=True)
    est_lu = serializers.BooleanField(source="lu", read_only=True)
    est_recu = serializers.BooleanField(source="lu", read_only=True)

    class Meta:
        model = Message
        fields = [
            "id",
            "conversation",
            "auteur",
            "auteur_username",
            "contenu",
            "lu",
            "cree_le",
            "envoyeur",
            "timestamp",
            "est_lu",
            "est_recu",
        ]
        read_only_fields = ["auteur", "lu", "cree_le"]

    def get_envoyeur(self, obj):
        request = self.context.get("request")
        if request and getattr(request, "user", None) and obj.auteur_id == request.user.id:
            return "moi"
        return "autre"


class ConversationSerializer(serializers.ModelSerializer):
    participants = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    class Meta:
        model = Conversation
        fields = [
            "id",
            "titre",
            "type_conversation",
            "patient",
            "participants",
            "cree_par",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = ["cree_par", "cree_le", "modifie_le"]


class NotificationInterneSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationInterne
        fields = ["id", "destinataire", "titre", "contenu", "niveau", "lu", "cree_le"]
        read_only_fields = ["destinataire", "cree_le"]


#EbaJioloLewis
