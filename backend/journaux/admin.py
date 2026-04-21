from django.contrib import admin

from .models import LogActivite


@admin.register(LogActivite)
class LogActiviteAdmin(admin.ModelAdmin):
    list_display = ("cree_le", "action", "acteur", "objet_type", "objet_id", "message")
    list_filter = ("action", "cree_le")
    search_fields = ("action", "acteur__username", "objet_type", "objet_id", "message")


#EbaJioloLewis
