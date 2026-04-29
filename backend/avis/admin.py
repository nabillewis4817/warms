from django.contrib import admin
from .models import Avis, StatistiquesAvis, MotifSignalement


@admin.register(Avis)
class AvisAdmin(admin.ModelAdmin):
    list_display = (
        "patient_nom", "type_avis", "note", "titre", "statut", 
        "nombre_signalements", "cree_le", "a_reponse"
    )
    list_filter = (
        "type_avis", "statut", "note", "cree_le", "nombre_signalements"
    )
    search_fields = (
        "patient__first_name", "patient__last_name", "patient__email",
        "titre", "commentaire"
    )
    readonly_fields = (
        "cree_le", "modifie_le", "patient_nom", "patient_email",
        "type_label", "statut_label", "a_reponse", "est_recent"
    )
    
    def patient_nom(self, obj):
        return obj.patient_nom
    patient_nom.short_description = "Patient"
    
    def patient_email(self, obj):
        return obj.patient_email
    patient_email.short_description = "Email"
    
    def type_label(self, obj):
        return obj.type_label
    type_label.short_description = "Type"
    
    def statut_label(self, obj):
        return obj.statut_label
    statut_label.short_description = "Statut"
    
    def a_reponse(self, obj):
        return "Oui" if obj.a_reponse else "Non"
    a_reponse.short_description = "Réponse"
    
    def est_recent(self, obj):
        return "Oui" if obj.est_recent else "Non"
    est_recent.short_description = "Récent"


@admin.register(StatistiquesAvis)
class StatistiquesAvisAdmin(admin.ModelAdmin):
    list_display = ("periode", "type_avis", "nombre_avis", "note_moyenne", "cree_le")
    list_filter = ("type_avis", "periode")
    search_fields = ("type_avis",)
    readonly_fields = ("cree_le", "modifie_le")


@admin.register(MotifSignalement)
class MotifSignalementAdmin(admin.ModelAdmin):
    list_display = ("nom", "description", "actif", "cree_le")
    list_filter = ("actif", "cree_le")
    search_fields = ("nom", "description")
    readonly_fields = ("cree_le",)
