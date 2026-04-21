from django.contrib import admin

from .models import CarnetQRCode


@admin.register(CarnetQRCode)
class CarnetQRCodeAdmin(admin.ModelAdmin):
    list_display = ("dossier", "actif", "cree_le")
    list_filter = ("actif",)
    search_fields = ("dossier__numero_dossier", "token")
