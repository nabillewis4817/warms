#!/usr/bin/env python3
"""
Script de diagnostic approfondi pour les erreurs 500
"""

import os
import sys
import django
import traceback
import logging

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

# Configuration du logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
from messagerie.models import Conversation, Message
from assistant_ia.services_ocr import extraire_texte_image
from io import BytesIO
from PIL import Image

User = get_user_model()

def test_500_errors():
    """Diagnostic approfondi des erreurs 500"""
    
    print("DIAGNOSTIC APPROFONDI DES ERREURS 500")
    print("=" * 60)
    
    # 1. Tester la vue marquer_lus directement
    print("\n1. TEST VUE MARQUER_LUS DIRECTEMENT:")
    try:
        from messagerie.views import ConversationViewSet
        
        # Créer une conversation de test
        user = User.objects.first()
        conversation = Conversation.objects.create(
            titre="Test conversation debug",
            type_conversation="interne",
            cree_par=user
        )
        
        # Créer quelques messages
        message1 = Message.objects.create(
            conversation=conversation,
            auteur=user,
            contenu="Message test 1",
            lu=False
        )
        message2 = Message.objects.create(
            conversation=conversation,
            auteur=user,
            contenu="Message test 2",
            lu=False
        )
        
        print(f"   Conversation créée: {conversation.id}")
        print(f"   Messages créés: {message1.id}, {message2.id}")
        
        # Simuler la vue marquer_lus
        viewset = ConversationViewSet()
        viewset.request = type('MockRequest', (), {
            'user': user
        })()
        
        # Créer un faux objet request
        class MockRequest:
            def __init__(self, user):
                self.user = user
        
        viewset.request = MockRequest(user)
        
        # Tester la méthode get_object
        viewset.kwargs = {'pk': conversation.id}
        conv_obj = viewset.get_object()
        print(f"   get_object() réussi: {conv_obj.id}")
        
        # Tester la logique de marquer_lus
        messages_non_lus = Message.objects.filter(
            conversation=conv_obj,
            lu=False
        )
        print(f"   Messages non lus trouvés: {messages_non_lus.count()}")
        
        # Tester la mise à jour individuelle
        messages_count = 0
        for message in messages_non_lus:
            try:
                message.lu = True
                message.save(update_fields=['lu'])
                messages_count += 1
                print(f"   Message {message.id} marqué comme lu")
            except Exception as e:
                print(f"   Erreur marquant message {message.id}: {e}")
                print(f"   Traceback: {traceback.format_exc()}")
        
        print(f"   Total messages marqués: {messages_count}")
        
    except Exception as e:
        print(f"   Erreur générale: {e}")
        print(f"   Traceback: {traceback.format_exc()}")
    
    # 2. Tester l'OCR directement
    print("\n2. TEST OCR DIRECTEMENT:")
    try:
        # Créer une image test
        img = Image.new('RGB', (100, 100), color='white')
        img_bytes = BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        
        # Créer un faux fichier uploadé
        from django.core.files.uploadedfile import InMemoryUploadedFile
        fake_file = InMemoryUploadedFile(
            name="test.png",
            content_type="image/png",
            size=img_bytes.getbuffer().nbytes,
            charset=None,
            content_type_extra=None
        )
        fake_file.file = img_bytes
        
        print("   Fichier test créé")
        
        # Tester la fonction OCR
        texte = extraire_texte_image(fake_file)
        print(f"   Texte extrait: {texte}")
        
    except Exception as e:
        print(f"   Erreur OCR: {e}")
        print(f"   Traceback: {traceback.format_exc()}")
    
    # 3. Vérifier les modèles et relations
    print("\n3. VÉRIFICATION MODÈLES:")
    try:
        # Vérifier le modèle Message
        print("   Modèle Message:")
        message_fields = [f.name for f in Message._meta.get_fields()]
        print(f"   Champs: {message_fields}")
        
        # Vérifier les relations ManyToMany
        many_to_many = [f.name for f in Message._meta.many_to_many]
        print(f"   Relations ManyToMany: {many_to_many}")
        
        # Vérifier si lus_par existe
        if hasattr(Message, 'lus_par'):
            print("   ✓ Champ lus_par trouvé")
        else:
            print("   ✗ Champ lus_par NON trouvé (normal)")
        
        if hasattr(Message, 'lu'):
            print("   ✓ Champ lu trouvé")
        else:
            print("   ✗ Champ lu NON trouvé (problème!)")
            
    except Exception as e:
        print(f"   Erreur vérification modèles: {e}")
        print(f"   Traceback: {traceback.format_exc()}")
    
    # 4. Tester les permissions
    print("\n4. VÉRIFICATION PERMISSIONS:")
    try:
        user = User.objects.first()
        print(f"   Utilisateur test: {user.username} (rôle: {user.role})")
        
        # Vérifier les rôles en base
        all_roles = User.objects.values_list('role', flat=True).distinct()
        print(f"   Rôles en base: {list(all_roles)}")
        
        # Tester la logique de vérification de rôle
        user_role = getattr(user, 'role', None)
        is_patient = user_role and user_role.lower() in ['patient', 'PATIENT']
        print(f"   Est patient: {is_patient}")
        
    except Exception as e:
        print(f"   Erreur permissions: {e}")
        print(f"   Traceback: {traceback.format_exc()}")
    
    print("\n" + "=" * 60)
    print("DIAGNOSTIC APPROFONDI TERMINÉ")

if __name__ == "__main__":
    test_500_errors()
