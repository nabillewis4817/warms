#!/usr/bin/env python
"""
Test HTTP de l'endpoint marquer_lus
"""
import os
import sys
import django
import requests

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from rest_framework_simplejwt.tokens import RefreshToken
from personnel.models import Utilisateur

def test_marquer_lus_http():
    """Tester l'endpoint marquer_lus via HTTP"""
    print("TEST HTTP DE L'ENDPOINT marquer_lus")
    
    try:
        # Obtenir un token
        user = Utilisateur.objects.filter(role='patient').first()
        if not user:
            print("Aucun utilisateur patient trouve")
            return False
            
        refresh = RefreshToken.for_user(user)
        token = str(refresh.access_token)
        
        headers = {'Authorization': f'Bearer {token}'}
        
        # Tester differentes conversations
        conversation_ids = [1, 2, 13, 14]
        
        for conv_id in conversation_ids:
            url = f"http://127.0.0.1:8000/api/v1/conversations/{conv_id}/marquer_lus/"
            print(f"\nTest: POST {url}")
            
            try:
                response = requests.post(url, headers=headers, timeout=10)
                print(f"Status: {response.status_code}")
                
                if response.status_code == 500:
                    print("Erreur 500 detectee!")
                    print("Response headers:", dict(response.headers))
                    print("Response content (first 1000 chars):")
                    print(response.text[:1000])
                    
                    # Essayer de parser l'erreur Django
                    if "<!DOCTYPE html>" in response.text:
                        print("C'est une page d'erreur Django")
                        # Extraire le message d'erreur
                        if "<title>" in response.text:
                            title_start = response.text.find("<title>") + 7
                            title_end = response.text.find("</title>")
                            if title_end > title_start:
                                error_title = response.text[title_start:title_end]
                                print(f"Titre de l'erreur: {error_title}")
                        
                        # Extraire le traceback
                        if "<pre>" in response.text:
                            pre_start = response.text.find("<pre>") + 5
                            pre_end = response.text.find("</pre>")
                            if pre_end > pre_start:
                                traceback = response.text[pre_start:pre_end]
                                print(f"Traceback:\n{traceback[:500]}...")
                else:
                    print(f"Response: {response.text}")
                    
            except requests.exceptions.RequestException as e:
                print(f"Erreur de requete: {e}")
        
        return True
        
    except Exception as e:
        print(f"Erreur generale: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("TEST HTTP POUR marquer_lus")
    print("="*50)
    
    success = test_marquer_lus_http()
    
    if success:
        print("\nTest termine")
    else:
        print("\nTest echoue")

if __name__ == "__main__":
    main()
