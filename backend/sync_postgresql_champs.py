#!/usr/bin/env python
"""
Script pour synchroniser la base PostgreSQL avec les nouveaux champs du modèle Patient
"""
import os
import sys
import django

# Configuration PostgreSQL
os.environ['DJANGO_SETTINGS_MODULE'] = 'gestion_cabinet.settings_postgresql'
django.setup()

import psycopg2
from psycopg2.extras import RealDictCursor

def synchroniser_champs_patients():
    """Ajouter les nouveaux champs manquants à la table PostgreSQL"""
    print("=== SYNCHRONISATION CHAMPS PATIENTS POSTGRESQL ===")
    
    try:
        conn = psycopg2.connect(
            dbname="warms",
            user="postgres",
            password="MacKenzie",
            host="localhost",
            port="5432"
        )
        
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            # Vérifier la structure actuelle
            try:
                cursor.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'patients_patient'")
                colonnes_actuelles = [row['column_name'] for row in cursor.fetchall()]
                print(f"Colonnes actuelles: {colonnes_actuelles}")
            except:
                print("Erreur lecture colonnes, utilisation méthode alternative")
                cursor.execute("SELECT * FROM patients_patient LIMIT 1")
                if cursor.description:
                    colonnes_actuelles = [desc[0] for desc in cursor.description]
                else:
                    colonnes_actuelles = []
            
            # Champs à ajouter
            champs_a_ajouter = {
                'groupe_sanguin': 'VARCHAR(8) DEFAULT \'inconnu\'',
                'derniere_consultation_date': 'DATE NULL',
                'derniere_consultation_lieu': 'VARCHAR(255) DEFAULT \'\'',
                'derniere_consultation_details': 'TEXT DEFAULT \'\''
            }
            
            # Ajouter les champs manquants
            for champ, definition in champs_a_ajouter.items():
                if champ not in colonnes_actuelles:
                    try:
                        cursor.execute(f"ALTER TABLE patients_patient ADD COLUMN {champ} {definition}")
                        print(f"Champ '{champ}' ajouté")
                    except Exception as e:
                        print(f"Erreur ajout champ '{champ}': {e}")
                else:
                    print(f"Champ '{champ}' déjà existe")
            
            conn.commit()
            
            # Vérifier la nouvelle structure
            cursor.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'patients_patient'")
            nouvelles_colonnes = [row['column_name'] for row in cursor.fetchall()]
            print(f"\nNouvelle structure: {nouvelles_colonnes}")
            
        conn.close()
        return True
        
    except Exception as e:
        print(f"Erreur synchronisation: {e}")
        return False

def tester_nouveaux_champs():
    """Tester les nouveaux champs avec PostgreSQL"""
    print("\n=== TEST NOUVEAUX CHAMPS POSTGRESQL ===")
    
    try:
        # Forcer Django à utiliser PostgreSQL
        os.environ['DJANGO_SETTINGS_MODULE'] = 'gestion_cabinet.settings_postgresql'
        import django
        django.setup()
        
        from patients.models import Patient
        
        # Créer un patient avec les nouveaux champs
        patient = Patient.objects.create(
            prenom='Test',
            nom='NouveauxChamps',
            email='test@nouveaux.com',
            telephone='123456789',
            groupe_sanguin='A+',
            derniere_consultation_date='2026-04-24',
            derniere_consultation_lieu='Cabinet principal',
            derniere_consultation_details='Consultation avec nouveaux champs',
            actif=True
        )
        
        print(f"Patient créé: ID {patient.id}")
        print(f"  Groupe sanguin: {patient.groupe_sanguin}")
        print(f"  Dernière consultation: {patient.derniere_consultation_date}")
        print(f"  Lieu: {patient.derniere_consultation_lieu}")
        print(f"  Détails: {patient.derniere_consultation_details}")
        
        # Modifier les champs
        patient.groupe_sanguin = 'B+'
        patient.derniere_consultation_details = 'Détails modifiés'
        patient.save()
        
        patient.refresh_from_db()
        print(f"Patient modifié: {patient.groupe_sanguin} - {patient.derniere_consultation_details}")
        
        # Supprimer le patient de test
        patient.delete()
        print("Patient de test supprimé")
        
        return True
        
    except Exception as e:
        print(f"Erreur test nouveaux champs: {e}")
        return False

def main():
    print("SYNCHRONISATION POSTGRESQL WARMS")
    print("=" * 50)
    
    # 1. Synchroniser les champs
    sync_ok = synchroniser_champs_patients()
    
    if sync_ok:
        # 2. Tester les nouveaux champs
        test_ok = tester_nouveaux_champs()
        
        print("\n" + "=" * 50)
        print("RÉSULTATS")
        print("=" * 50)
        print(f"Synchronisation: {'OK' if sync_ok else 'KO'}")
        print(f"Test nouveaux champs: {'OK' if test_ok else 'KO'}")
        
        if sync_ok and test_ok:
            print("\n🎉 SYNCHRONISATION POSTGRESQL RÉUSSIE !")
            print("✅ Nouveaux champs ajoutés à la base")
            print("✅ Tests de création/modification/suppression OK")
            print("✅ WARMS prêt avec PostgreSQL")
        else:
            print("\n❌ Problèmes lors de la synchronisation")
    else:
        print("\nEchec de la synchronisation PostgreSQL")
    
    print("\nNettoyage du fichier de synchronisation...")
    try:
        os.remove(__file__)
        print("   Fichier supprimé")
    except:
        print("   Impossible de supprimer le fichier")
    
    return sync_ok

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
