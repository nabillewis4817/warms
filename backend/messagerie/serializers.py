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
    patient_nom = serializers.SerializerMethodField()
    dernier_message = serializers.SerializerMethodField()
    dernier_message_le = serializers.SerializerMethodField()
    non_lus = serializers.SerializerMethodField()
    participants_info = serializers.SerializerMethodField()
    en_ligne = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            "id",
            "titre",
            "type_conversation",
            "patient",
            "patient_nom",
            "participants",
            "participants_info",
            "en_ligne",
            "dernier_message",
            "dernier_message_le",
            "non_lus",
            "cree_par",
            "cree_le",
            "modifie_le",
        ]
        read_only_fields = ["cree_par", "cree_le", "modifie_le"]

    def get_patient_nom(self, obj):
        if obj.patient_id and obj.patient:
            return f"{obj.patient.prenom} {obj.patient.nom}"
        return None

    def get_dernier_message(self, obj):
        dernier = obj.messages.order_by("-cree_le").first()
        return dernier.contenu if dernier else None

    def get_dernier_message_le(self, obj):
        dernier = obj.messages.order_by("-cree_le").first()
        return dernier.cree_le if dernier else None

    def get_non_lus(self, obj):
        request = self.context.get("request")
        user = getattr(request, "user", None) if request else None
        if not user or not getattr(user, "is_authenticated", False):
            return 0
        return obj.messages.filter(lu=False).exclude(auteur_id=user.id).count()

    def get_participants_info(self, obj):
        request = self.context.get("request")
        user = getattr(request, "user", None) if request else None
        infos = []
        for participant in obj.participants.all():
            if user and participant.id == user.id:
                continue
            infos.append(
                {
                    "id": participant.id,
                    "nom": participant.get_full_name() or participant.username,
                    "role": participant.role,
                    "en_ligne": participant.est_en_ligne,
                }
            )
        return infos

    def get_en_ligne(self, obj):
        request = self.context.get("request")
        user = getattr(request, "user", None) if request else None
        for participant in obj.participants.all():
            if user and participant.id == user.id:
                continue
            if participant.est_en_ligne:
                return True
        return False


class NotificationInterneSerializer(serializers.ModelSerializer):
    class Meta:
        model = NotificationInterne
        fields = ["id", "destinataire", "titre", "contenu", "niveau", "lu", "cree_le"]
        read_only_fields = ["destinataire", "cree_le"]


#EbaJioloLewis
