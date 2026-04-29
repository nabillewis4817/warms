#!/usr/bin/env python
"""
Extraire le traceback complet de l'erreur FieldError
"""
import os
import sys
import django
import requests
import re

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from rest_framework_simplejwt.tokens import RefreshToken
from personnel.models import Utilisateur

def extract_field_error():
    """Extraire le traceback complet de l'erreur FieldError"""
    print("EXTRACTION DU TRACEBACK FIELDERROR")
    
    try:
        # Obtenir un token
        user = Utilisateur.objects.filter(role='patient').first()
        if not user:
            print("Aucun utilisateur patient trouve")
            return False
            
        refresh = RefreshToken.for_user(user)
        token = str(refresh.access_token)
        
        headers = {'Authorization': f'Bearer {token}'}
        
        # Tester une conversation qui existe
        url = "http://127.0.0.1:8000/api/v1/conversations/1/marquer_lus/"
        
        try:
            response = requests.post(url, headers=headers, timeout=10)
            
            if response.status_code == 500 and "<!DOCTYPE html>" in response.text:
                print("Page d'erreur Django detectee")
                
                # Extraire le traceback
                traceback_pattern = r'<pre>(.*?)</pre>'
                matches = re.findall(traceback_pattern, response.text, re.DOTALL)
                
                if matches:
                    print("\nTRACEBACK COMPLET:")
                    print("="*60)
                    for i, match in enumerate(matches):
                        print(f"\n--- Traceback {i+1} ---")
                        print(match[:2000])  # Limiter la taille
                        if len(match) > 2000:
                            print("... (tronque)")
                else:
                    print("Aucun traceback trouve")
                
                # Extraire les details de l'erreur
                error_pattern = r'<h2>(.*?)</h2>'
                error_matches = re.findall(error_pattern, response.text)
                if error_matches:
                    print(f"\nDETAILS DE L'ERREUR:")
                    for match in error_matches:
                        print(f"- {match}")
                
                # Chercher des indices sur le champ probleme
                if "FieldError" in response.text:
                    print("\nRECHERCHE DU CHAMP PROBLEME:")
                    # Chercher des references a des champs
                    field_pattern = r'"([^"]+)"'
                    field_matches = re.findall(field_pattern, response.text)
                    unique_fields = list(set(field_matches))
                    for field in unique_fields[:10]:  # Limiter l'affichage
                        print(f"- Champ potentiel: {field}")
                
            else:
                print(f"Status: {response.status_code}")
                print(f"Response: {response.text[:500]}")
                
        except requests.exceptions.RequestException as e:
            print(f"Erreur de requete: {e}")
        
        return True
        
    except Exception as e:
        print(f"Erreur generale: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("EXTRACTION DES DETAILS DE L'ERREUR FIELDERROR")
    print("="*50)
    
    success = extract_field_error()
    
    if success:
        print("\nExtraction terminee")
    else:
        print("\nExtraction echouee")

if __name__ == "__main__":
    main()
