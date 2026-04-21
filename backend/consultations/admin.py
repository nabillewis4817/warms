from django.contrib import admin

from .models import ActeRealise, Consultation, PhotoClinique, SchemaDentaire


@admin.register(Consultation)
class ConsultationAdmin(admin.ModelAdmin):
    list_display = ("patient", "date", "praticien", "rendez_vous")
    search_fields = ("patient__prenom", "patient__nom", "motif", "diagnostic")
    list_filter = ("date",)


@admin.register(ActeRealise)
class ActeRealiseAdmin(admin.ModelAdmin):
    list_display = ("consultation", "libelle", "dent", "cree_le")
    search_fields = ("libelle", "dent", "consultation__patient__nom")


@admin.register(SchemaDentaire)
class SchemaDentaireAdmin(admin.ModelAdmin):
    list_display = ("consultation", "modifie_le")


@admin.register(PhotoClinique)
class PhotoCliniqueAdmin(admin.ModelAdmin):
    list_display = ("consultation", "type_photo", "cree_le")
    list_filter = ("type_photo",)


#EbaJioloLewis
