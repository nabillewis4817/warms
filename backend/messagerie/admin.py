from django.contrib import admin

from .models import Conversation, Message, NotificationInterne, ParticipantConversation


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ("id", "titre", "type_conversation", "patient", "cree_par", "modifie_le")
    list_filter = ("type_conversation",)
    search_fields = ("titre", "patient__nom", "patient__prenom", "cree_par__username")


@admin.register(ParticipantConversation)
class ParticipantConversationAdmin(admin.ModelAdmin):
    list_display = ("conversation", "utilisateur", "est_admin", "a_mute", "rejoint_le")
    list_filter = ("est_admin", "a_mute")
    search_fields = ("utilisateur__username", "conversation__id")


@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ("conversation", "auteur", "lu", "cree_le")
    list_filter = ("lu",)
    search_fields = ("auteur__username", "contenu")


@admin.register(NotificationInterne)
class NotificationInterneAdmin(admin.ModelAdmin):
    list_display = ("destinataire", "titre", "lu", "cree_le")
    list_filter = ("lu",)
    search_fields = ("destinataire__username", "titre", "contenu")


#EbaJioloLewis
