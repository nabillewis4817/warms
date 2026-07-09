from django.db import migrations, models


def dedupliquer_emails(apps, schema_editor):
    """
    Appelé APRÈS que la colonne soit déjà nullable.
    1. Convertit les chaînes vides en NULL.
    2. Pour chaque email dupliqué (insensible à la casse), conserve le patient
       ayant l'id le plus élevé et met les autres à NULL.
    """
    # Utiliser du SQL brut pour éviter tout problème de modèle intermédiaire.
    schema_editor.execute(
        "UPDATE patients_patient SET email = NULL WHERE email = ''"
    )
    schema_editor.execute("""
        UPDATE patients_patient
        SET email = NULL
        WHERE id NOT IN (
            SELECT MAX(id)
            FROM patients_patient
            WHERE email IS NOT NULL
            GROUP BY LOWER(email)
        )
        AND email IS NOT NULL
    """)


class Migration(migrations.Migration):

    dependencies = [
        ('patients', '0005_patient_photo'),
    ]

    operations = [
        # 1. Rendre la colonne nullable d'abord (supprime NOT NULL)
        migrations.AlterField(
            model_name='patient',
            name='email',
            field=models.EmailField(blank=True, null=True, max_length=254),
        ),
        # 2. Nettoyer les doublons maintenant que NULL est autorisé
        migrations.RunPython(
            dedupliquer_emails,
            reverse_code=migrations.RunPython.noop,
        ),
        # 3. Ajouter la contrainte UNIQUE
        migrations.AlterField(
            model_name='patient',
            name='email',
            field=models.EmailField(blank=True, null=True, unique=True, max_length=254),
        ),
    ]
