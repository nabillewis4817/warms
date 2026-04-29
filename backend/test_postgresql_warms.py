#!/usr/bin/env python
"""
Script pour tester WARMS avec PostgreSQL
"""
import os
import sys

# Forcer l'utilisation de la configuration PostgreSQL
os.environ['DJANGO_SETTINGS_MODULE'] = 'gestion_cabinet.settings_postgresql'

import django
django.setup()

from django.db import connection
from patients.models import Patient
from django.contrib.auth import get_user_model

def main():
    print("=== TEST WARMS AVEC POSTGRESQL ===")
    
    # Vérifier la connexion
    print(f"Engine: {connection.vendor}")
    
    # Lister les patients
    try:
        patients = Patient.objects.all()
        print(f"Nombre total de patients: {patients.count()}")
        
        for patient in patients:
            print(f"   - {patient.prenom} {patient.nom} ({patient.email})")
            
    except Exception as e:
        print(f"Erreur lecture patients: {e}")
    
    # Vérifier les utilisateurs
    try:
        Utilisateur = get_user_model()
        utilisateurs = Utilisateur.objects.all()
        print(f"Nombre total d'utilisateurs: {utilisateurs.count()}")
        
        for user in utilisateurs:
            print(f"   - {user.username} (role: {getattr(user, 'role', 'N/A')})")
            
    except Exception as e:
        print(f"Erreur lecture utilisateurs: {e}")

if __name__ == '__main__':
    main()
