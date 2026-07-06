from django.db import migrations, models


def convertir_email_vide_en_null(apps, schema_editor):
    """Convertit les chaînes vides en NULL pour permettre la contrainte unique."""
    Patient = apps.get_model('patients', 'Patient')
    Patient.objects.filter(email='').update(email=None)


class Migration(migrations.Migration):

    dependencies = [
        ('patients', '0005_patient_photo'),
    ]

    operations = [
        # 1. Convertir les "" en NULL (data migration)
        migrations.RunPython(
            convertir_email_vide_en_null,
            reverse_code=migrations.RunPython.noop,
        ),
        # 2. Changer le champ : null=True + unique=True
        migrations.AlterField(
            model_name='patient',
            name='email',
            field=models.EmailField(
                blank=True,
                null=True,
                unique=True,
                max_length=254,
            ),
        ),
    ]
