from django.contrib import admin

from .models import DossierPatient, PageCarnet, Patient, PieceJointeDossier


@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = ("prenom", "nom", "telephone", "email", "actif", "cree_le")
    list_filter = ("actif",)
    search_fields = ("prenom", "nom", "telephone", "email")


@admin.register(DossierPatient)
class DossierPatientAdmin(admin.ModelAdmin):
    list_display = ("numero_dossier", "patient", "cree_le")
    search_fields = ("numero_dossier", "patient__prenom", "patient__nom")


@admin.register(PageCarnet)
class PageCarnetAdmin(admin.ModelAdmin):
    list_display = ("dossier", "numero_page", "modifie_le")
    search_fields = ("dossier__numero_dossier",)


@admin.register(PieceJointeDossier)
class PieceJointeDossierAdmin(admin.ModelAdmin):
    list_display = ("dossier", "libelle", "fichier", "cree_le")
    search_fields = ("dossier__numero_dossier", "libelle", "fichier")
