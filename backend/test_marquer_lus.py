#!/usr/bin/env python
"""
Test specifique pour l'action marquer_lus
"""
import os
import sys
import django

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from messagerie.models import Conversation, Message
from messagerie.views import ConversationViewSet
from django.contrib.auth.models import AnonymousUser
from rest_framework.test import APIRequestFactory
from rest_framework.request import Request

def test_marquer_lus_direct():
    """Tester la methode marquer_lus directement"""
    print("TEST DIRECT DE LA METHODE marquer_lus")
    
    try:
        # Recuperer une conversation existante
        conversation = Conversation.objects.first()
        if not conversation:
            print("Aucune conversation trouvee")
            return False
            
        print(f"Conversation ID: {conversation.id}")
        
        # Compter les messages non lus
        messages_non_lus = Message.objects.filter(
            conversation=conversation,
            lu=False
        )
        print(f"Messages non lus avant: {messages_non_lus.count()}")
        
        # Creer une vue et une requete factice
        viewset = ConversationViewSet()
        factory = APIRequestFactory()
        request = factory.post(f'/conversations/{conversation.id}/marquer_lus/')
        request.user = AnonymousUser()
        
        # Simuler get_object
        viewset.kwargs = {'pk': conversation.id}
        def mock_get_object():
            return conversation
        viewset.get_object = mock_get_object
        
        # Tester la methode
        response = viewset.marquer_lus(request, pk=conversation.id)
        print(f"Response status: {response.status_code}")
        print(f"Response data: {response.data}")
        
        # Verifier le resultat
        messages_non_lus_apres = Message.objects.filter(
            conversation=conversation,
            lu=False
        )
        print(f"Messages non lus apres: {messages_non_lus_apres.count()}")
        
        return True
        
    except Exception as e:
        print(f"Erreur lors du test: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_message_fields():
    """Tester les champs du modele Message"""
    print("\nTEST DES CHAMPS DU MODELE MESSAGE")
    
    try:
        # Verifier la structure du modele
        message = Message.objects.first()
        if not message:
            print("Aucun message trouve")
            return False
            
        print(f"Message ID: {message.id}")
        print(f"Conversation: {message.conversation.id}")
        print(f"Contenu: {message.contenu[:50]}...")
        print(f"Lu: {message.lu}")
        print(f"Date: {message.cree_le}")
        
        # Lister tous les champs
        fields = [f.name for f in Message._meta.get_fields()]
        print(f"Champs du modele: {fields}")
        
        return True
        
    except Exception as e:
        print(f"Erreur: {e}")
        return False

def main():
    print("TEST SPECIFIQUE POUR marquer_lus")
    print("="*50)
    
    success1 = test_message_fields()
    success2 = test_marquer_lus_direct()
    
    if success1 and success2:
        print("\n✅ Tous les tests ont reussi")
    else:
        print("\n❌ Certains tests ont echoue")

if __name__ == "__main__":
    main()
