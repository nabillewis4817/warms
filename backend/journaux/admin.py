from django.contrib import admin

from .models import LogActivite


@admin.register(LogActivite)
class LogActiviteAdmin(admin.ModelAdmin):
    list_display = ("cree_le", "action", "type_action", "acteur", "objet_type", "objet_id", "details")
    list_filter = ("action", "type_action", "cree_le")
    search_fields = ("action", "type_action", "details", "acteur__username", "objet_type", "objet_id")
    readonly_fields = ("cree_le", "modifie_le", "utilisateur_nom", "icone_type")
    
    def utilisateur_nom(self, obj):
        return obj.utilisateur_nom
    utilisateur_nom.short_description = "Utilisateur"
    
    def icone_type(self, obj):
        return obj.icone_type
    icone_type.short_description = "Icône"


#EbaJioloLewis
