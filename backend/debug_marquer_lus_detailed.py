#!/usr/bin/env python
"""
Debug detaille de la methode marquer_lus avec logs
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

def debug_marquer_lus_step_by_step():
    """Debug pas a pas de la methode marquer_lus"""
    print("DEBUG PAS A PAS DE marquer_lus")
    
    try:
        # Etape 1: Recuperer une conversation
        print("1. Recuperation d'une conversation...")
        conversation = Conversation.objects.first()
        if not conversation:
            print("   Aucune conversation trouvee")
            return False
        print(f"   Conversation ID: {conversation.id}")
        print(f"   Conversation titre: {conversation.titre}")
        
        # Etape 2: Verifier les messages
        print("2. Verification des messages...")
        messages = Message.objects.filter(conversation=conversation)
        print(f"   Total messages: {messages.count()}")
        
        messages_non_lus = messages.filter(lu=False)
        print(f"   Messages non lus: {messages_non_lus.count()}")
        
        # Etape 3: Tester la requete manuellement
        print("3. Test de la requete manuelle...")
        try:
            # Simuler la requete exacte de la vue
            messages_query = Message.objects.filter(
                conversation=conversation,
                lu=False
            )
            print(f"   Requete cree: {messages_query.query}")
            print(f"   Resultats: {messages_query.count()}")
            
            # Tester le premier message
            first_msg = messages_query.first()
            if first_msg:
                print(f"   Premier message ID: {first_msg.id}")
                print(f"   Premier message lu: {first_msg.lu}")
                print(f"   Champs du message: {[f.name for f in Message._meta.get_fields()]}")
                
        except Exception as e:
            print(f"   Erreur dans la requete: {e}")
            import traceback
            traceback.print_exc()
            return False
        
        # Etape 4: Tester la vue avec une requete factice
        print("4. Test de la vue...")
        try:
            viewset = ConversationViewSet()
            factory = APIRequestFactory()
            request = factory.post(f'/conversations/{conversation.id}/marquer_lus/')
            
            # Ajouter l'utilisateur
            user = AnonymousUser()
            request.user = user
            
            # Creer une Request DRF
            drf_request = Request(request)
            
            # Configurer le viewset
            viewset.request = drf_request
            viewset.format_kwarg = None
            viewset.kwargs = {'pk': conversation.id}
            
            # Mock get_object
            viewset.get_object = lambda: conversation
            
            print("   Appel de marquer_lus...")
            response = viewset.marquer_lus(drf_request, pk=conversation.id)
            print(f"   Response status: {response.status_code}")
            print(f"   Response data: {response.data}")
            
        except Exception as e:
            print(f"   Erreur dans la vue: {e}")
            print(f"   Type d'erreur: {type(e)}")
            import traceback
            traceback.print_exc()
            
            # Si c'est une FieldError, analyser le champ
            if "FieldError" in str(type(e)):
                print("   C'est une FieldError!")
                print(f"   Message: {str(e)}")
                
                # Essayer d'identifier le champ probleme
                if "Cannot resolve keyword" in str(e):
                    import re
                    match = re.search(r"'([^']+)'", str(e))
                    if match:
                        field_name = match.group(1)
                        print(f"   Champ probleme: '{field_name}'")
                        
                        # Verifier si ce champ existe dans le modele
                        fields = [f.name for f in Message._meta.get_fields()]
                        if field_name in fields:
                            print(f"   Le champ '{field_name}' existe dans le modele")
                        else:
                            print(f"   Le champ '{field_name}' n'existe PAS dans le modele")
                            print(f"   Champs disponibles: {fields}")
            
            return False
        
        # Etape 5: Verifier le resultat
        print("5. Verification du resultat...")
        messages_non_lus_apres = Message.objects.filter(
            conversation=conversation,
            lu=False
        )
        print(f"   Messages non lus apres: {messages_non_lus_apres.count()}")
        
        return True
        
    except Exception as e:
        print(f"Erreur generale: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("DEBUG DETAILLE DE marquer_lus")
    print("="*50)
    
    success = debug_marquer_lus_step_by_step()
    
    if success:
        print("\nDebug termine avec succes")
    else:
        print("\nDebug echoue")

if __name__ == "__main__":
    main()
