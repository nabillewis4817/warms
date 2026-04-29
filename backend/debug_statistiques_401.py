#!/usr/bin/env python
"""
Script pour diagnostiquer les erreurs 401 sur les endpoints statistiques
"""
import os
import sys
import django

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from django.urls import reverse

def tester_endpoints_statistiques():
    """Tester tous les endpoints statistiques"""
    print("=== TEST ENDPOINTS STATISTIQUES ===")
    
    Utilisateur = get_user_model()
    
    # Créer un utilisateur de test
    utilisateur, created = Utilisateur.objects.get_or_create(
        username='test_stats',
        defaults={
            'email': 'test@stats.com',
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
    
    client = APIClient()
    
    # Test 1: Sans authentification
    print("\n1. TEST SANS AUTHENTIFICATION:")
    try:
        response = client.get('/api/v1/statistiques/vue-generale/')
        print(f"   Status: {response.status_code}")
        if response.status_code == 401:
            print("   ✓ 401 attendu (non authentifié)")
        else:
            print(f"   ✗ Inattendu: {response.data}")
    except Exception as e:
        print(f"   Erreur: {e}")
    
    # Test 2: Avec authentification
    print("\n2. TEST AVEC AUTHENTIFICATION:")
    client.force_authenticate(user=utilisateur)
    try:
        response = client.get('/api/v1/statistiques/vue-generale/')
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print("   ✓ 200 OK (authentifié)")
            print(f"   Données reçues: {len(str(response.data))} caractères")
        elif response.status_code == 401:
            print("   ✗ 401 non attendu (authentifié)")
            print(f"   Erreur: {response.data}")
        else:
            print(f"   ✗ Statut inattendu: {response.data}")
    except Exception as e:
        print(f"   Erreur: {e}")
    
    # Test 3: Test endpoint absentéisme
    print("\n3. TEST ENDPOINT ABSENTEISME:")
    try:
        response = client.get('/api/v1/statistiques/absenteisme/')
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print("   ✓ 200 OK")
        elif response.status_code == 401:
            print("   ✗ 401")
            print(f"   Erreur: {response.data}")
        else:
            print(f"   ✗ Statut inattendu: {response.data}")
    except Exception as e:
        print(f"   Erreur: {e}")
    
    # Test 4: Test endpoint parcours patient
    print("\n4. TEST ENDPOINT PARCOURS PATIENT:")
    try:
        response = client.get('/api/v1/statistiques/parcours-patient/')
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            print("   ✓ 200 OK")
        elif response.status_code == 404:
            print("   ✓ 404 attendu (pas de profil patient)")
        elif response.status_code == 401:
            print("   ✗ 401 non attendu")
            print(f"   Erreur: {response.data}")
        else:
            print(f"   ✗ Statut inattendu: {response.data}")
    except Exception as e:
        print(f"   Erreur: {e}")
    
    # Test 5: Vérifier les URLs
    print("\n5. VERIFICATION URLs:")
    from django.urls import get_resolver
    from django.urls.resolvers import URLResolver, URLPattern
    
    def print_urls(urlpatterns, prefix=''):
        for pattern in urlpatterns:
            if isinstance(pattern, URLResolver):
                print_urls(pattern.url_patterns, prefix + str(pattern.pattern))
            elif isinstance(pattern, URLPattern):
                full_path = prefix + str(pattern.pattern)
                if 'statistiques' in full_path:
                    print(f"   URL trouvée: {full_path} -> {pattern.callback}")
    
    resolver = get_resolver()
    print_urls(resolver.url_patterns)
    
    # Test 6: Vérifier configuration middleware
    print("\n6. VERIFICATION MIDDLEWARE:")
    from django.conf import settings
    middleware_classes = getattr(settings, 'MIDDLEWARE', [])
    auth_middleware = [m for m in middleware_classes if 'auth' in m.lower() or 'session' in m.lower()]
    print(f"   Middleware d'authentification trouvés: {auth_middleware}")
    
    if not auth_middleware:
        print("   ⚠️ Aucun middleware d'authentification trouvé!")
    else:
        print("   ✓ Middleware d'authentification présents")

def tester_auth_manuelle():
    """Tester l'authentification manuellement"""
    print("\n=== TEST AUTHENTIFICATION MANUELLE ===")
    
    Utilisateur = get_user_model()
    utilisateur = Utilisateur.objects.filter(username='test_stats').first()
    
    if not utilisateur:
        print("   Utilisateur de test non trouvé")
        return
    
    print(f"   Utilisateur: {utilisateur.username}")
    print(f"   Role: {utilisateur.role}")
    print(f"   Actif: {utilisateur.is_active}")
    print(f"   Staff: {utilisateur.is_staff}")
    print(f"   Superuser: {utilisateur.is_superuser}")
    
    # Tester la connexion
    from django.contrib.auth import authenticate, login
    from django.test import RequestFactory
    
    factory = RequestFactory()
    request = factory.get('/api/v1/statistiques/vue-generale/')
    
    user = authenticate(username='test_stats', password='test123')
    if user:
        print("   ✓ Authentification réussie")
        login(request, user)
        print(f"   Utilisateur dans request: {request.user}")
        print(f"   Est authentifié: {request.user.is_authenticated}")
    else:
        print("   ✗ Échec de l'authentification")

def main():
    print("DIAGNOSTIC ERREURS 401 STATISTIQUES")
    print("=" * 50)
    
    tester_endpoints_statistiques()
    tester_auth_manuelle()
    
    print("\n" + "=" * 50)
    print("ANALYSE ET SOLUTIONS")
    print("=" * 50)
    print("1. Si 401 sans authentification: Normal")
    print("2. Si 401 avec authentification: Problème")
    print("3. Causes possibles:")
    print("   - Token JWT non envoyé dans le header")
    print("   - Token expiré")
    print("   - Middleware d'authentification manquant")
    print("   - Configuration CORS incorrecte")
    print("4. Solutions:")
    print("   - Vérifier que le frontend envoie le token")
    print("   - Ajouter Authorization: Bearer <token>")
    print("   - Vérifier la configuration REST_FRAMEWORK")
    
    print("\nNettoyage du fichier de diagnostic...")
    try:
        os.remove(__file__)
        print("   Fichier supprimé")
    except:
        print("   Impossible de supprimer le fichier")

if __name__ == '__main__':
    main()
