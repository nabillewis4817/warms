# Generated manually for Appel and TauxAbsenteisme models

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("consultations", "0002_initial"),
        ("rendez_vous", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("patients", "0002_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="Appel",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("date_appel", models.DateField()),
                ("heure_appel", models.TimeField(auto_now_add=True)),
                (
                    "statut",
                    models.CharField(
                        choices=[
                            ("present", "Présent"),
                            ("absent_justifie", "Absent (justifié)"),
                            ("absent_non_justifie", "Absent (non justifié)"),
                            ("en_retard", "En retard"),
                            ("annule", "Annulé"),
                            ("en_attente", "En attente"),
                        ],
                        default="en_attente",
                        max_length=20,
                    ),
                ),
                ("motif_absence", models.TextField(blank=True, help_text="Motif de l'absence si applicable")),
                (
                    "justificatif_fourni",
                    models.BooleanField(
                        default=False,
                        help_text="Un justificatif a été fourni pour l'absence",
                    ),
                ),
                (
                    "fichier_justificatif",
                    models.FileField(
                        blank=True,
                        help_text="Fichier du justificatif d'absence",
                        null=True,
                        upload_to="appels/justificatifs/",
                    ),
                ),
                (
                    "duree_retard",
                    models.DurationField(
                        blank=True,
                        help_text="Durée du retard si en retard",
                        null=True,
                    ),
                ),
                (
                    "notes_appel",
                    models.TextField(blank=True, help_text="Notes prises lors de l'appel"),
                ),
                (
                    "notes_suivi",
                    models.TextField(blank=True, help_text="Notes de suivi après l'appel"),
                ),
                ("cree_le", models.DateTimeField(auto_now_add=True)),
                ("modifie_le", models.DateTimeField(auto_now=True)),
                (
                    "cree_par",
                    models.ForeignKey(
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="appels_crees",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "patient",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="appels",
                        to="patients.patient",
                    ),
                ),
                (
                    "praticien",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="appels_effectues",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "rendez_vous",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="appels",
                        to="rendez_vous.rendezvous",
                    ),
                ),
            ],
            options={
                "verbose_name": "Appel",
                "verbose_name_plural": "Appels",
                "ordering": ["-date_appel", "-heure_appel"],
            },
        ),
        migrations.CreateModel(
            name="TauxAbsenteisme",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("periode_debut", models.DateField()),
                ("periode_fin", models.DateField()),
                (
                    "type_periode",
                    models.CharField(
                        choices=[
                            ("jour", "Journalier"),
                            ("semaine", "Hebdomadaire"),
                            ("mois", "Mensuel"),
                            ("annee", "Annuel"),
                        ],
                        default="mois",
                        help_text="Type de période pour le calcul",
                        max_length=10,
                    ),
                ),
                ("total_appels", models.IntegerField(default=0)),
                ("total_presents", models.IntegerField(default=0)),
                ("total_absents", models.IntegerField(default=0)),
                ("total_absents_justifies", models.IntegerField(default=0)),
                ("total_absents_non_justifies", models.IntegerField(default=0)),
                ("total_en_retard", models.IntegerField(default=0)),
                ("total_annules", models.IntegerField(default=0)),
                ("taux_presence", models.FloatField(default=0.0, help_text="Taux de présence (%)")),
                ("taux_absenteisme", models.FloatField(default=0.0, help_text="Taux d'absentéisme (%)")),
                (
                    "taux_absenteisme_justifie",
                    models.FloatField(default=0.0, help_text="Taux d'absentéisme justifié (%)"),
                ),
                ("taux_retard", models.FloatField(default=0.0, help_text="Taux de retard (%)")),
                ("cree_le", models.DateTimeField(auto_now_add=True)),
                ("modifie_le", models.DateTimeField(auto_now=True)),
                (
                    "praticien",
                    models.ForeignKey(
                        blank=True,
                        help_text="Filtrer par praticien (optionnel)",
                        null=True,
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="taux_absenteisme",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "verbose_name": "Taux d'absentéisme",
                "verbose_name_plural": "Taux d'absentéisme",
                "ordering": ["-periode_debut"],
            },
        ),
        migrations.AddIndex(
            model_name="appel",
            index=models.Index(fields=["date_appel"], name="consultatio_date_ap_6a8f2a_idx"),
        ),
        migrations.AddIndex(
            model_name="appel",
            index=models.Index(fields=["patient", "date_appel"], name="consultatio_patient_8c4e1b_idx"),
        ),
        migrations.AddIndex(
            model_name="appel",
            index=models.Index(fields=["statut"], name="consultatio_statut_2f91ac_idx"),
        ),
        migrations.AlterUniqueTogether(
            name="appel",
            unique_together={("patient", "date_appel", "rendez_vous")},
        ),
        migrations.AddIndex(
            model_name="tauxabsenteisme",
            index=models.Index(fields=["periode_debut", "periode_fin"], name="consultatio_periode_9d3e21_idx"),
        ),
        migrations.AddIndex(
            model_name="tauxabsenteisme",
            index=models.Index(fields=["type_periode"], name="consultatio_type_pe_4b7c82_idx"),
        ),
        migrations.AddIndex(
            model_name="tauxabsenteisme",
            index=models.Index(fields=["praticien"], name="consultatio_praticie_1a2f90_idx"),
        ),
        migrations.AlterUniqueTogether(
            name="tauxabsenteisme",
            unique_together={("periode_debut", "periode_fin", "praticien", "type_periode")},
        ),
    ]
