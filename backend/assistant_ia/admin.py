from django.contrib import admin

from .models import CompteRenduIA, MessageAssistantIA, OCRImportCarnet, RecommandationIA


@admin.register(OCRImportCarnet)
class OCRImportCarnetAdmin(admin.ModelAdmin):
    list_display = ("id", "patient", "dossier", "cree_par", "cree_le")
    search_fields = ("patient__nom", "patient__prenom", "dossier__numero_dossier")


@admin.register(RecommandationIA)
class RecommandationIAAdmin(admin.ModelAdmin):
    list_display = ("patient", "type_recommandation", "score_confiance", "resolue", "cree_le")
    list_filter = ("type_recommandation", "resolue")
    search_fields = ("patient__nom", "patient__prenom", "message")


@admin.register(CompteRenduIA)
class CompteRenduIAAdmin(admin.ModelAdmin):
    list_display = ("consultation", "genere_par", "cree_le")
    search_fields = ("consultation__patient__nom", "consultation__patient__prenom")


@admin.register(MessageAssistantIA)
class MessageAssistantIAAdmin(admin.ModelAdmin):
    list_display = ("dossier", "auteur", "cree_le")
    search_fields = ("dossier__numero_dossier", "question", "reponse")


#EbaJioloLewis
