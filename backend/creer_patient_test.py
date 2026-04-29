#!/usr/bin/env python
import os
import sys
import django

# Configuration Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from personnel.models import Utilisateur
from patients.models import Patient

def verifier_et_creer_patient():
    """Vérifier si l'utilisateur a un profil patient et en créer un si nécessaire"""
    print("=== Vérification des profils patients ===")
    
    # Lister tous les utilisateurs
    utilisateurs = Utilisateur.objects.all()
    print(f"Nombre total d'utilisateurs: {utilisateurs.count()}")
    
    for utilisateur in utilisateurs:
        print(f"\nUtilisateur: {utilisateur.username} (ID: {utilisateur.id}, Rôle: {utilisateur.role})")
        
        # Vérifier si l'utilisateur a déjà un profil patient
        patient_existant = Patient.objects.filter(user=utilisateur).first()
        
        if patient_existant:
            print(f"  [OK] Profil patient existant: {patient_existant.prenom} {patient_existant.nom}")
        else:
            print(f"  [ERREUR] Aucun profil patient trouve")
            
            # Créer un profil patient si c'est un patient
            if utilisateur.role and utilisateur.role.lower() in ['patient']:
                print(f"  [CREATION] Creation d'un profil patient pour {utilisateur.username}...")
                
                patient = Patient.objects.create(
                    user=utilisateur,
                    nom=utilisateur.last_name or utilisateur.username,
                    prenom=utilisateur.first_name or "Patient",
                    email=utilisateur.email,
                    telephone=getattr(utilisateur, 'telephone', ''),
                    date_naissance='1990-01-01',  # Valeur par défaut
                    groupe_sanguin='O+',  # Valeur par défaut
                    symptomes='Aucun symptome enregistre',  # Valeur par défaut
                    consultations_precedentes='Aucune consultation anterieure',  # Valeur par défaut
                    actif=True
                )
                
                print(f"  [SUCCES] Profil patient cree: {patient.prenom} {patient.nom}")
            else:
                print(f"  [INFO] Utilisateur n'est pas un patient (role: {utilisateur.role})")

if __name__ == "__main__":
    verifier_et_creer_patient()
