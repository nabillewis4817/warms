#!/usr/bin/env python3
"""
Test spécifique pour vérifier les corrections des erreurs 500
"""

import os
import sys
import django
import requests
import json

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
from messagerie.models import Conversation, Message

User = get_user_model()

def test_specific_fixes():
    """Tester les corrections spécifiques"""
    
    print("TEST SPECIFIQUE DES CORRECTIONS")
    print("=" * 50)
    
    # 1. Créer une conversation de test
    print("\n1. CRÉATION CONVERSATION DE TEST:")
    try:
        user = User.objects.first()
        refresh = RefreshToken.for_user(user)
        access_token = str(refresh.access_token)
        print(f"   Utilisateur: {user.username}")
        
        # Créer une conversation
        conv_data = {"titre": "Test conversation fix", "type_conversation": "interne"}
        base_url = "http://127.0.0.1:8000/api/v1"
        headers = {"Authorization": f"Bearer {access_token}"}
        
        response = requests.post(f"{base_url}/conversations/", 
                             json=conv_data, headers=headers, timeout=5)
        print(f"   Creation conversation Status: {response.status_code}")
        
        if response.status_code == 201:
            conv_data = response.json()
            conv_id = conv_data['id']
            print(f"   Conversation creee avec ID: {conv_id}")
            
            # 2. Tester marquer_lus avec la bonne conversation
            print(f"\n2. TEST MARQUER_LUS SUR CONVERSATION {conv_id}:")
            response = requests.post(f"{base_url}/conversations/{conv_id}/marquer_lus/", 
                                 headers=headers, timeout=5)
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 200:
                print("   Succes - marquer_lus fonctionne!")
                print(f"   Reponse: {response.json()}")
            else:
                print(f"   Erreur: {response.status_code}")
                if response.status_code == 500:
                    print("   Erreur 500 persiste - verifier les logs")
        
        # 3. Tester patients/me avec un patient
        print(f"\n3. TEST PATIENTS/ME:")
        # Créer un utilisateur patient si nécessaire
        patient_user = User.objects.filter(role__in=['patient', 'PATIENT']).first()
        if patient_user:
            patient_refresh = RefreshToken.for_user(patient_user)
            patient_token = str(patient_refresh.access_token)
            patient_headers = {"Authorization": f"Bearer {patient_token}"}
            
            response = requests.get(f"{base_url}/patients/me/", headers=patient_headers, timeout=5)
            print(f"   Status: {response.status_code}")
            
            if response.status_code == 403:
                print("   ❌ 403 persiste - problème de rôle")
            elif response.status_code == 200:
                print("   ✅ Succès - patients/me fonctionne!")
            else:
                print(f"   Erreur inattendue: {response.status_code}")
        
        # 4. Tester OCR avec fallback
        print(f"\n4. TEST OCR AVEC FALLBACK:")
        import io
        from PIL import Image
        
        # Créer une image test
        img = Image.new('RGB', (100, 100), color='white')
        img_bytes = io.BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        
        files = {'image': ('test.png', img_bytes, 'image/png')}
        response = requests.post(f"{base_url}/ia/ocr-carnet/", 
                             files=files, headers=headers, timeout=10)
        print(f"   Status: {response.status_code}")
        
        if response.status_code == 200:
            print("   ✅ Succès - OCR fonctionne!")
            data = response.json()
            print(f"   Texte extrait: {data.get('texte_extrait', 'N/A')}")
        elif response.status_code == 500:
            print("   Erreur 500 - OCR a encore des problèmes")
        else:
            print(f"   Erreur: {response.status_code}")
            
    except Exception as e:
        print(f"   Erreur generale: {e}")
    
    print("\n" + "=" * 50)
    print("TEST TERMINE")

if __name__ == "__main__":
    test_specific_fixes()
