#!/usr/bin/env python
"""
Script de diagnostic pour les erreurs API persistantes
"""
import os
import sys
import django
import requests
from datetime import datetime

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken
from patients.models import Patient
from personnel.models import Utilisateur

def get_auth_token():
    """Obtenir un token JWT pour les tests"""
    try:
        # Utiliser un utilisateur existant ou en créer un pour les tests
        user = Utilisateur.objects.filter(role='patient').first()
        if not user:
            print("❌ Aucun utilisateur patient trouvé")
            return None
            
        refresh = RefreshToken.for_user(user)
        access_token = str(refresh.access_token)
        print(f"✅ Token obtenu pour l'utilisateur: {user.username}")
        return access_token
    except Exception as e:
        print(f"❌ Erreur lors de l'obtention du token: {e}")
        return None

def test_endpoint(token, method, url, data=None, files=None):
    """Tester un endpoint API"""
    headers = {'Authorization': f'Bearer {token}'} if token else {}
    
    try:
        if method == 'GET':
            response = requests.get(url, headers=headers, timeout=10)
        elif method == 'POST':
            if files:
                headers.pop('Content-Type', None)  # Let requests set the content type for file uploads
                response = requests.post(url, headers=headers, files=files, timeout=10)
            else:
                response = requests.post(url, headers=headers, json=data, timeout=10)
        
        print(f"\n{'='*60}")
        print(f"🔍 Test: {method} {url}")
        print(f"📊 Status: {response.status_code}")
        print(f"📄 Response: {response.text[:500]}...")
        
        return response.status_code, response.text
        
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur de connexion: {e}")
        return None, str(e)

def main():
    print("🚀 DÉMARRAGE DU DIAGNOSTIC DES ERREURS PERSISTANTES")
    print(f"⏰ Heure: {datetime.now()}")
    
    base_url = "http://127.0.0.1:8000/api/v1"
    token = get_auth_token()
    
    if not token:
        print("❌ Impossible d'obtenir un token d'authentification")
        return
    
    # Tests des endpoints problématiques
    test_cases = [
        # 403 Forbidden errors
        ("GET", f"{base_url}/patients/me/", None, None),
        ("GET", f"{base_url}/prescriptions/me/", None, None),
        
        # 500 Internal Server Error on conversations
        ("POST", f"{base_url}/conversations/1/marquer_lus/", {}, None),
        ("POST", f"{base_url}/conversations/2/marquer_lus/", {}, None),
        
        # 500 Internal Server Error on OCR
        ("POST", f"{base_url}/ia/ocr-carnet/", None, {"image": ("test.jpg", b"fake image data", "image/jpeg")}),
        
        # 401 Unauthorized on conversations messages
        ("GET", f"{base_url}/conversations/1/messages/", None, None),
    ]
    
    results = []
    for method, url, data, files in test_cases:
        status, response = test_endpoint(token, method, url, data, files)
        results.append((method, url, status, response))
    
    # Résumé
    print(f"\n{'='*60}")
    print("📋 RÉSUMÉ DES ERREURS")
    print(f"{'='*60}")
    
    error_counts = {}
    for method, url, status, response in results:
        if status and status >= 400:
            error_type = f"{status} {method}"
            error_counts[error_type] = error_counts.get(error_type, 0) + 1
            print(f"❌ {status} {method} {url}")
    
    print(f"\n📊 Statistiques des erreurs:")
    for error_type, count in error_counts.items():
        print(f"   {error_type}: {count} occurrence(s)")
    
    # Tests spécifiques pour diagnostiquer
    print(f"\n🔍 TESTS DE DIAGNOSTIC SPÉCIFIQUES:")
    
    # Test 1: Vérifier le modèle Message
    try:
        from messagerie.models import Message
        messages_count = Message.objects.count()
        print(f"✅ Modèle Message: {messages_count} message(s) trouvé(s)")
        
        # Tester la structure du champ 'lu'
        first_message = Message.objects.first()
        if first_message:
            print(f"✅ Champ 'lu': {first_message.lu} (type: {type(first_message.lu)})")
    except Exception as e:
        print(f"❌ Erreur modèle Message: {e}")
    
    # Test 2: Vérifier le service OCR
    try:
        from assistant_ia.services_ocr import extraire_texte_image
        from io import BytesIO
        
        # Créer une fausse image pour tester
        fake_image = BytesIO(b"fake image data")
        fake_image.name = "test.jpg"
        
        texte = extraire_texte_image(fake_image)
        print(f"✅ Service OCR: '{texte[:50]}...'")
    except Exception as e:
        print(f"❌ Erreur service OCR: {e}")
    
    # Test 3: Vérifier les rôles utilisateurs
    try:
        patients = Utilisateur.objects.filter(role__in=['patient', 'PATIENT'])
        print(f"✅ Utilisateurs patients: {patients.count()} trouvé(s)")
        
        for patient in patients[:3]:  # Limiter à 3 pour l'affichage
            print(f"   - {patient.username} (rôle: '{patient.role}')")
    except Exception as e:
        print(f"❌ Erreur vérification rôles: {e}")

if __name__ == "__main__":
    main()
