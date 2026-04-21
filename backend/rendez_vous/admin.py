from django.contrib import admin

from .models import RendezVous


@admin.register(RendezVous)
class RendezVousAdmin(admin.ModelAdmin):
    list_display = ("patient", "debut", "fin", "statut", "praticien", "infirmiere")
    list_filter = ("statut",)
    search_fields = ("patient__prenom", "patient__nom", "motif", "notes")


#EbaJioloLewis
