"""Applique la migration consultations 0003 si les tables manquent (contourne l'historique incohérent)."""
import os
import sys

BACKEND_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "gestion_cabinet.settings")
django.setup()

from django.core.management import call_command
from django.db import connection
from django.db.migrations.recorder import MigrationRecorder
from django.db.utils import ProgrammingError


def table_exists(name: str) -> bool:
    with connection.cursor() as cursor:
        cursor.execute("SELECT to_regclass(%s)", [f"public.{name}"])
        row = cursor.fetchone()
        return row is not None and row[0] is not None


def is_applied(recorder: MigrationRecorder, app: str, name: str) -> bool:
    return (app, name) in recorder.applied_migrations()


def main() -> int:
    recorder = MigrationRecorder(connection)

    # Corriger l'historique patients.0002 si qr_codes est déjà appliqué
    if not is_applied(recorder, "patients", "0002_initial"):
        if is_applied(recorder, "qr_codes", "0001_initial"):
            print("Correction historique: fake patients.0002_initial")
            recorder.record_applied("patients", "0002_initial")

    # Base déjà en place : marquer 0002 comme appliquée si besoin
    if table_exists("consultations_consultation") and not is_applied(recorder, "consultations", "0002_initial"):
        print("Correction historique: fake consultations.0002_initial")
        recorder.record_applied("consultations", "0002_initial")

    if table_exists("consultations_tauxabsenteisme") and table_exists("consultations_appel"):
        if not is_applied(recorder, "consultations", "0003_appel_taux_absenteisme"):
            recorder.record_applied("consultations", "0003_appel_taux_absenteisme")
            print("Tables déjà présentes — migration 0003 enregistrée.")
        else:
            print("Migration 0003 déjà appliquée.")
        return 0

    print("Application de consultations.0003_appel_taux_absenteisme …")
    call_command("migrate", "consultations", "0003_appel_taux_absenteisme", verbosity=1)
    print("OK — tables Appel et TauxAbsenteisme créées.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERREUR: {exc}", file=sys.stderr)
        sys.exit(1)
