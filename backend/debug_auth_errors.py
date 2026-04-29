#!/usr/bin/env python3
"""
Script de diagnostic pour les erreurs d'authentification et conversations
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
from messagerie.models import Conversation, Message, NotificationInterne

User = get_user_model()

def test_auth_and_endpoints():
    """Tester l'authentification et les endpoints problématiques"""
    
    print("DIAGNOSTIC DES ERREURS D'AUTHENTIFICATION ET CONVERSATIONS")
    print("=" * 70)
    
    # 1. Vérifier les utilisateurs existants
    print("\n1. UTILISATEURS EXISTANTS:")
    users = User.objects.all()
    for user in users:
        print(f"   - {user.username} ({user.role}) - Actif: {user.is_active}")
    
    if not users.exists():
        print("   Aucun utilisateur trouvé!")
        # Créer un utilisateur de test
        user = User.objects.create_user(
            username='test_dentiste',
            email='test@warms.com',
            password='test123456',
            first_name='Test',
            last_name='Dentiste',
            role='chirurgien_dentiste'
        )
        print(f"   Utilisateur de test créé: {user.username}")
    
    # 2. Tester l'authentification JWT
    print("\n2. TEST AUTHENTIFICATION JWT:")
    try:
        user = User.objects.first()
        refresh = RefreshToken.for_user(user)
        access_token = str(refresh.access_token)
        print(f"   Token généré pour {user.username}")
        
        # 3. Tester les endpoints problématiques
        base_url = "http://127.0.0.1:8000/api/v1"
        headers = {"Authorization": f"Bearer {access_token}"}
        
        print("\n3. TEST DES ENDPOINTS:")
        
        # Test patients/me/
        print("   a) Patients/me/:")
        try:
            response = requests.get(f"{base_url}/patients/me/", headers=headers, timeout=5)
            print(f"      Status: {response.status_code}")
            if response.status_code == 403:
                print("      403 Forbidden - Vérifier les permissions")
            elif response.status_code == 401:
                print("      401 Unauthorized - Token invalide")
            elif response.status_code == 200:
                print("      Succès")
        except Exception as e:
            print(f"      Erreur: {e}")
        
        # Test notifications/badges/
        print("   b) Notifications/badges/:")
        try:
            response = requests.get(f"{base_url}/notifications/badges/", headers=headers, timeout=5)
            print(f"      Status: {response.status_code}")
            if response.status_code == 403:
                print("      403 Forbidden - Vérifier les permissions")
            elif response.status_code == 401:
                print("      401 Unauthorized - Token invalide")
            elif response.status_code == 200:
                print("      Succès")
                print(f"      Données: {response.json()}")
        except Exception as e:
            print(f"      Erreur: {e}")
        
        # Test conversations/
        print("   c) Conversations/:")
        try:
            response = requests.get(f"{base_url}/conversations/", headers=headers, timeout=5)
            print(f"      Status: {response.status_code}")
            if response.status_code == 500:
                print("      500 Internal Server Error - Problème backend")
                # Essayer de créer une conversation pour diagnostiquer
                try:
                    conv_data = {"titre": "Test conversation", "type_conversation": "interne"}
                    response = requests.post(f"{base_url}/conversations/", 
                                         json=conv_data, headers=headers, timeout=5)
                    print(f"      Création conversation Status: {response.status_code}")
                    if response.status_code == 500:
                        print("      Erreur 500 lors de la création - Vérifier les modèles/vues")
                except Exception as e2:
                    print(f"      Erreur création: {e2}")
            elif response.status_code == 200:
                print("      Succès")
                print(f"      Données: {response.json()}")
        except Exception as e:
            print(f"      Erreur: {e}")
        
        # Test conversations/10/marquer_lus/
        print("   d) Conversations/10/marquer_lus/:")
        try:
            response = requests.post(f"{base_url}/conversations/10/marquer_lus/", 
                                 headers=headers, timeout=5)
            print(f"      Status: {response.status_code}")
            if response.status_code == 500:
                print("      500 Internal Server Error - Problème avec la vue marquer_lus")
            elif response.status_code == 404:
                print("      404 Not Found - Conversation 10 n'existe pas")
        except Exception as e:
            print(f"      Erreur: {e}")
        
        # Test IA endpoints
        print("\n4. TEST ENDPOINTS IA:")
        
        # Test ia/ocr-carnet/
        print("   a) IA/OCR-Carnet/:")
        try:
            # Créer un faux fichier pour tester
            import io
            from PIL import Image
            img = Image.new('RGB', (100, 100), color='white')
            img_bytes = io.BytesIO()
            img.save(img_bytes, format='PNG')
            img_bytes.seek(0)
            
            files = {'image': ('test.png', img_bytes, 'image/png')}
            response = requests.post(f"{base_url}/ia/ocr-carnet/", 
                                 files=files, headers=headers, timeout=5)
            print(f"      Status: {response.status_code}")
            if response.status_code == 404:
                print("      404 Not Found - Endpoint non trouvé")
            elif response.status_code == 200:
                print("      Succès")
        except Exception as e:
            print(f"      Erreur: {e}")
        
        # Test ia/warms-general/
        print("   b) IA/Warms-General/:")
        try:
            data = {"question": "Test question", "patient_id": 1}
            response = requests.post(f"{base_url}/ia/warms-general/", 
                                 json=data, headers=headers, timeout=5)
            print(f"      Status: {response.status_code}")
            if response.status_code == 404:
                print("      404 Not Found - Endpoint non trouvé")
            elif response.status_code == 200:
                print("      Succès")
        except Exception as e:
            print(f"      Erreur: {e}")
        
    except Exception as e:
        print(f"   Erreur génération token: {e}")
    
    # 4. Vérifier les modèles de messagerie
    print("\n5. VERIFICATION MODELES MESSAGERIE:")
    try:
        conversations_count = Conversation.objects.count()
        messages_count = Message.objects.count()
        notifications_count = NotificationInterne.objects.count()
        
        print(f"   - Conversations: {conversations_count}")
        print(f"   - Messages: {messages_count}")
        print(f"   - Notifications: {notifications_count}")
        
        # Vérifier la structure des champs
        if conversations_count > 0:
            conv = Conversation.objects.first()
            print(f"   - Structure conversation: {conv.__dict__}")
        
        if notifications_count > 0:
            notif = NotificationInterne.objects.first()
            print(f"   - Structure notification: {notif.__dict__}")
            
    except Exception as e:
        print(f"   Erreur modèles: {e}")
    
    print("\n" + "=" * 70)
    print("DIAGNOSTIC TERMINE")

if __name__ == "__main__":
    test_auth_and_endpoints()
