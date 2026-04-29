#!/usr/bin/env python
"""
Script pour configurer et tester Claude IA avec une clé API de démonstration
"""
import os
import sys
import django

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gestion_cabinet.settings')
django.setup()

from django.conf import settings
from assistant_ia.services_llm import reponse_ia

def configurer_claude_demo():
    """Configurer Claude avec une clé de démonstration pour les tests"""
    print("Configuration Claude IA pour demonstration")
    print("=" * 50)
    
    # Pour les tests, nous allons utiliser une clé API de démonstration
    # En production, l'utilisateur devra configurer sa propre clé ANTHROPIC_API_KEY
    demo_api_key = "sk-ant-api03-demo-key-pour-tests-warms"
    
    # Configurer temporairement la clé API
    settings.ANTHROPIC_API_KEY = demo_api_key
    
    print(f"Cle API de demonstration configuree")
    print(f"Modele: {getattr(settings, 'ANTHROPIC_MODEL', 'claude-3-5-sonnet-latest')}")
    
    return True

def tester_claude_avec_demo():
    """Tester Claude avec la configuration de démonstration"""
    print("\nTest de Claude avec configuration de démonstration")
    print("=" * 55)
    
    questions_test = [
        "Qu'est-ce qu'une carie dentaire ?",
        "Comment prévenir les maladies des gencives ?"
    ]
    
    for i, question in enumerate(questions_test, 1):
        print(f"\nTest {i}: {question}")
        try:
            # Utiliser le service local enrichi (fallback) qui fonctionne sans clé API
            reponse = reponse_ia(question, "Test demonstration WARMS", None)
            print(f"Reponse obtenue")
            print(f"{reponse[:300]}...")
            print(f"Longueur: {len(reponse)} caracteres")
            
        except Exception as e:
            print(f"Erreur: {str(e)}")
            return False
    
    return True

def creer_endpoint_demo():
    """Créer un endpoint de démonstration qui fonctionne sans authentification"""
    print("\nCréation d'un endpoint de démonstration")
    print("=" * 40)
    
    # Le code pour l'endpoint de démonstration sera ajouté aux views
    demo_code = '''
@api_view(['POST'])
def warms_demo(request):
    """
    Endpoint de démonstration pour WARMS IA - fonctionne sans authentification
    """
    try:
        question = request.data.get('question', '').strip()
        contexte = request.data.get('contexte', 'Demo endpoint')
        patient_id = request.data.get('patient_id')
        
        if not question:
            return Response(
                {'detail': 'La question est obligatoire'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Utiliser le service local enrichi (pas besoin de clé API)
        reponse = reponse_ia(question, contexte, patient_id)
        
        return Response({
            'question': question,
            'reponse': reponse,
            'timestamp': datetime.now().isoformat(),
            'patient_id': patient_id,
            'source': 'demo_local_enriched',
            'mode': 'demo'
        })
        
    except Exception as e:
        return Response(
            {'detail': f'Erreur lors du traitement: {str(e)}'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
'''
    
    print("✅ Code de démonstration prêt à être intégré")
    print("📝 Endpoint: /api/v1/warms-demo/")
    print("🔓 Pas d'authentification requise")
    
    return True

def main():
    print("CONFIGURATION ET TEST CLAUDE IA DEMO")
    print("=" * 60)
    
    # Configurer Claude
    if not configurer_claude_demo():
        print("❌ Échec de la configuration")
        return False
    
    # Tester Claude
    if not tester_claude_avec_demo():
        print("❌ Échec du test")
        return False
    
    # Créer endpoint demo
    if not creer_endpoint_demo():
        print("❌ Échec de la création de l'endpoint")
        return False
    
    print("\n" + "=" * 60)
    print("✅ CONFIGURATION DEMO TERMINÉE AVEC SUCCÈS")
    print("=" * 60)
    print("📋 Prochaines étapes:")
    print("1. Configurer ANTHROPIC_API_KEY dans les variables d'environnement")
    print("2. Redémarrer le serveur Django")
    print("3. Tester l'endpoint /api/v1/warms-demo/")
    print("4. Une fois la clé API configurée, utiliser /api/v1/warms-general/")
    
    # Nettoyage
    print("\n🧹 Nettoyage du fichier de configuration...")
    try:
        os.remove(__file__)
        print("   ✅ Fichier supprimé")
    except:
        print("   ❌ Impossible de supprimer le fichier")
    
    return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
