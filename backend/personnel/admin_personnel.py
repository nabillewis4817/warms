from django.contrib import admin
from .models_personnel import Personnel, HistoriqueStatut, Presence


@admin.register(Personnel)
class PersonnelAdmin(admin.ModelAdmin):
    list_display = (
        "matricule", "utilisateur", "service", "specialite", 
        "statut", "date_embauche", "anciennete"
    )
    list_filter = ("service", "statut", "date_embauche")
    search_fields = (
        "matricule", "utilisateur__first_name", "utilisateur__last_name",
        "utilisateur__email", "specialite"
    )
    readonly_fields = ("cree_le", "modifie_le", "nom_complet", "anciennete")
    
    def nom_complet(self, obj):
        return obj.nom_complet
    nom_complet.short_description = "Nom complet"
    
    def anciennete(self, obj):
        return f"{obj.anciennete} ans"
    anciennete.short_description = "Ancienneté"


@admin.register(HistoriqueStatut)
class HistoriqueStatutAdmin(admin.ModelAdmin):
    list_display = (
        "personnel", "ancien_statut", "nouveau_statut", 
        "modifie_par", "date_changement"
    )
    list_filter = ("ancien_statut", "nouveau_statut", "date_changement")
    search_fields = (
        "personnel__utilisateur__first_name", "personnel__utilisateur__last_name",
        "raison"
    )
    readonly_fields = ("date_changement",)


@admin.register(Presence)
class PresenceAdmin(admin.ModelAdmin):
    list_display = (
        "personnel", "date", "heure_arrivee", "heure_depart", "statut"
    )
    list_filter = ("statut", "date")
    search_fields = (
        "personnel__utilisateur__first_name", "personnel__utilisateur__last_name",
        "notes"
    )
    date_hierarchy = "date"
