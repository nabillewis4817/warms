#!/usr/bin/env python
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from personnel.models import Utilisateur
from django.contrib.auth.hashers import make_password

# Réinitialiser le mot de passe pour Shelby
user = Utilisateur.objects.filter(username='Shelby').first()
if user:
    user.password = make_password('shelby66')
    user.save()
    print('✅ Mot de passe mis à jour pour Shelby')
    print(f'Username: {user.username}')
    print(f'Email: {user.email}')
    print(f'Role: {getattr(user, "role", None)}')
    print(f'Is active: {user.is_active}')
else:
    print('❌ Utilisateur Shelby non trouvé')
    
# Vérifier l'authentification
from django.contrib.auth import authenticate
auth_user = authenticate(username='Shelby', password='shelby66')
if auth_user:
    print('✅ Authentification réussie pour Shelby')
else:
    print('❌ Authentification échouée pour Shelby')
