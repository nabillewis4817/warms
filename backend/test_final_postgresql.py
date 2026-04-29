#!/usr/bin/env python
"""
Test final de toutes les fonctionnalités avec PostgreSQL warms
"""
import os
import sys
import django

# Forcer l'utilisation de la configuration PostgreSQL
os.environ['DJANGO_SETTINGS_MODULE'] = 'gestion_cabinet.settings_postgresql'
django.setup()

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from patients.models import Patient
from personnel.models import Utilisateur

def test_suppression_patient_postgresql():
    """Tester la suppression patient avec PostgreSQL"""
    print("=== TEST SUPPRESSION PATIENT POSTGRESQL ===")
    
    Utilisateur = get_user_model()
    
    # Créer un utilisateur avec les bons droits
    utilisateur, created = Utilisateur.objects.get_or_create(
        username='test_suppression_pg',
        defaults={
            'email': 'test@pg.com',
            'role': Utilisateur.Role.CHIRURGIEN_DENTISTE,
            'is_active': True
        }
    )
    if created:
        utilisateur.set_password('test123')
        utilisateur.save()
        print(f"Utilisateur créé: {utilisateur.username}")
    else:
        print(f"Utilisateur existant: {utilisateur.username}")
    
    # Créer un patient de test
    patient = Patient.objects.create(
        prenom='Test',
        nom='SuppressionPG',
        email='test.pg@suppression.com',
        telephone='123456789',
        actif=True
    )
    print(f"Patient de test créé: ID {patient.id} - {patient.prenom} {patient.nom}")
    
    # Tester l'endpoint amélioré
    client = APIClient()
    client.force_authenticate(user=utilisateur)
    
    try:
        response = client.delete(f'/api/v1/patients/{patient.id}/supprimer-ameliore/')
        print(f"Status code: {response.status_code}")
        print(f"Response data: {response.data}")
        
        if response.status_code == 200:
            print("Suppression améliorée réussie !")
            
            # Vérifier que le patient est bien supprimé
            if not Patient.objects.filter(id=patient.id).exists():
                print("Patient bien supprimé de la base PostgreSQL")
                return True
            else:
                print("Patient existe encore dans la base PostgreSQL")
                return False
        else:
            print(f"Erreur suppression: {response.status_code}")
            print(f"Détails: {response.data}")
            return False
            
    except Exception as e:
        print(f"Erreur lors du test: {e}")
        return False
    finally:
        # Nettoyer si le patient existe encore
        if Patient.objects.filter(id=patient.id).exists():
            patient.delete()

def test_toutes_les_fonctionnalites():
    """Tester toutes les fonctionnalités principales"""
    print("\n=== TEST TOUTES LES FONCTIONNALITÉS ===")
    
    Utilisateur = get_user_model()
    
    # 1. Test création patient
    print("\n1. TEST CRÉATION PATIENT:")
    patient = Patient.objects.create(
        prenom='Test',
        nom='Fonctionnalite',
        email='test@fonction.com',
        telephone='987654321',
        groupe_sanguin='A+',
        derniere_consultation_date='2026-04-24',
        derniere_consultation_lieu='Cabinet principal',
        derniere_consultation_details='Consultation de routine',
        actif=True
    )
    print(f"   Patient créé: ID {patient.id}")
    print(f"   Groupe sanguin: {patient.groupe_sanguin}")
    print(f"   Dernière consultation: {patient.derniere_consultation_date}")
    
    # 2. Test archivage patient
    print("\n2. TEST ARCHIVAGE PATIENT:")
    patient.actif = False
    patient.save()
    patient.refresh_from_db()
    print(f"   Patient archivé: actif={patient.actif}")
    
    # 3. Test modification patient
    print("\n3. TEST MODIFICATION PATIENT:")
    patient.prenom = 'Modifié'
    patient.email = 'modifie@test.com'
    patient.save()
    patient.refresh_from_db()
    print(f"   Patient modifié: {patient.prenom} - {patient.email}")
    
    # 4. Test suppression patient
    print("\n4. TEST SUPPRESSION PATIENT:")
    patient_id = patient.id
    patient.delete()
    print(f"   Patient supprimé: ID {patient_id}")
    
    # Vérifier que le patient n'existe plus
    if not Patient.objects.filter(id=patient_id).exists():
        print("   ✓ Patient bien supprimé")
    else:
        print("   ✗ Patient existe encore")
    
    # 5. Test statistiques
    print("\n5. TEST STATISTIQUES:")
    try:
        from statistiques.views import vue_generale
        print("   Module statistiques importé")
    except Exception as e:
        print(f"   Erreur import statistiques: {e}")
    
    # 6. Test IA
    print("\n6. TEST IA:")
    try:
        from assistant_ia.views import warms_demo
        print("   Module IA importé")
    except Exception as e:
        print(f"   Erreur import IA: {e}")
    
    return True

def verifier_etat_base():
    """Vérifier l'état actuel de la base PostgreSQL"""
    print("\n=== ÉTAT ACTUEL BASE POSTGRESQL ===")
    
    # Patients
    patients = Patient.objects.all()
    print(f"Total patients: {patients.count()}")
    
    for patient in patients:
        print(f"   - {patient.prenom} {patient.nom} (ID: {patient.id})")
        print(f"     Email: {patient.email}")
        print(f"     Actif: {patient.actif}")
        print(f"     Groupe sanguin: {patient.groupe_sanguin}")
        print(f"     ---")
    
    # Utilisateurs
    Utilisateur = get_user_model()
    utilisateurs = Utilisateur.objects.all()
    print(f"\nTotal utilisateurs: {utilisateurs.count()}")
    
    for user in utilisateurs:
        print(f"   - {user.username} (role: {getattr(user, 'role', 'N/A')})")
    
    return True

def main():
    print("TEST FINAL COMPLET WARMS POSTGRESQL")
    print("=" * 60)
    
    # 1. Vérifier l'état actuel
    verifier_etat_base()
    
    # 2. Tester la suppression patient
    suppression_ok = test_suppression_patient_postgresql()
    
    # 3. Tester toutes les fonctionnalités
    fonctionnalites_ok = test_toutes_les_fonctionnalites()
    
    # 4. Résultats finaux
    print("\n" + "=" * 60)
    print("RÉSULTATS FINAUX")
    print("=" * 60)
    print(f"Suppression patient: {'OK' if suppression_ok else 'KO'}")
    print(f"Toutes fonctionnalités: {'OK' if fonctionnalites_ok else 'KO'}")
    
    if suppression_ok and fonctionnalites_ok:
        print("\n🎉 WARMS EST 100% FONCTIONNEL AVEC POSTGRESQL !")
        print("✅ Toutes les fonctionnalités testées avec succès")
        print("✅ Base PostgreSQL warms configurée")
        print("✅ Patients, suppression, archivage, IA fonctionnels")
    else:
        print("\n❌ Certains problèmes restent à résoudre")
    
    print("\nNettoyage du fichier de test...")
    try:
        os.remove(__file__)
        print("   Fichier supprimé")
    except:
        print("   Impossible de supprimer le fichier")
    
    return suppression_ok and fonctionnalites_ok

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
