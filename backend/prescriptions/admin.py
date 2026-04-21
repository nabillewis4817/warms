from django.contrib import admin

from .models import LignePrescription, Prescription


class LignePrescriptionInline(admin.TabularInline):
    model = LignePrescription
    extra = 0


@admin.register(Prescription)
class PrescriptionAdmin(admin.ModelAdmin):
    list_display = ("patient", "cree_le", "consultation", "praticien", "titre")
    search_fields = ("patient__prenom", "patient__nom", "titre", "note_praticien")
    inlines = [LignePrescriptionInline]


@admin.register(LignePrescription)
class LignePrescriptionAdmin(admin.ModelAdmin):
    list_display = ("prescription", "medicament", "posologie", "duree")
    search_fields = ("medicament", "posologie", "duree", "remarques")


#EbaJioloLewis
