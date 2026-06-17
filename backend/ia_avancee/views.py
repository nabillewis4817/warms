import json
import requests
import time
from datetime import datetime
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
import re
from urllib.parse import quote
import hashlib

# Configuration des APIs externes
GOOGLE_API_KEY = "YOUR_GOOGLE_API_KEY"  # À configurer
OPENAI_API_KEY = "YOUR_OPENAI_API_KEY"    # À configurer
PUBMED_API_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"

def verifier_api_key(request):
    """Vérifie la clé API dans les headers"""
    api_key = request.headers.get('X-API-Key')
    if not api_key or api_key != "YOUR_API_KEY":  # Clé temporaire
        return False
    return True

def recherche_google_scholar(query, limit=10):
    """Recherche sur Google Scholar (simulation)"""
    # Note: En production, utiliser une API réelle comme Google Scholar API
    results = []
    
    # Simulation de résultats pour démonstration
    for i in range(min(limit, 5)):
        results.append({
            'titre': f"Étude médicale sur {query} - Article {i+1}",
            'url': f"https://scholar.google.com/scholar?q={quote(query)}&hl=fr",
            'snippet': f"Résultat de recherche {i+1} pour {query} avec informations médicales pertinentes...",
            'source': 'Google Scholar',
            'date': datetime.now().strftime('%Y-%m-%d'),
            'pertinence': 0.9 - (i * 0.1)
        })
    
    return results

def recherche_pubmed(query, limit=10):
    """Recherche sur PubMed"""
    try:
        # Recherche d'articles
        search_url = f"{PUBMED_API_URL}esearch.fcgi?db=pubmed&term={quote(query)}&retmax={limit}"
        search_response = requests.get(search_url)
        
        if search_response.status_code == 200:
            # Parser la réponse pour obtenir les IDs
            import xml.etree.ElementTree as ET
            root = ET.fromstring(search_response.text)
            id_list = root.find('IdList')
            
            if id_list is not None:
                pmids = [id_elem.text for id_elem in id_list.findall('Id')]
                
                # Obtenir les détails des articles
                if pmids:
                    fetch_url = f"{PUBMED_API_URL}efetch.fcgi?db=pubmed&id={','.join(pmids)}&retmode=xml"
                    fetch_response = requests.get(fetch_url)
                    
                    if fetch_response.status_code == 200:
                        articles_root = ET.fromstring(fetch_response.text)
                        results = []
                        
                        for article in articles_root.findall('.//PubmedArticle'):
                            title_elem = article.find('.//ArticleTitle')
                            abstract_elem = article.find('.//AbstractText')
                            
                            title = title_elem.text if title_elem is not None else "Titre non disponible"
                            abstract = abstract_elem.text if abstract_elem is not None else "Résumé non disponible"
                            
                            results.append({
                                'titre': title,
                                'url': f"https://pubmed.ncbi.nlm.nih.gov/{pmids[results.count if 'results' in locals() else 0]}/",
                                'snippet': abstract[:200] + "..." if len(abstract) > 200 else abstract,
                                'source': 'PubMed',
                                'date': datetime.now().strftime('%Y-%m-%d'),
                                'pertinence': 0.85
                            })
                        
                        return results[:limit]
        
        return []
        
    except Exception as e:
        print(f"Erreur recherche PubMed: {e}")
        return []

def rechercher_sources_medicales(query, contexte=None):
    """Recherche multi-sources médicales"""
    results = []
    
    # Recherche Google Scholar
    scholar_results = recherche_google_scholar(query, 5)
    results.extend(scholar_results)
    
    # Recherche PubMed
    pubmed_results = recherche_pubmed(query, 5)
    results.extend(pubmed_results)
    
    # Trier par pertinence
    results.sort(key=lambda x: x['pertinence'], reverse=True)
    
    return results[:10]

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def recherche_web(request):
    """Recherche web avancée"""
    if not verifier_api_key(request):
        return Response({'error': 'Clé API invalide'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        data = request.data
        query = data.get('query', '')
        limit = data.get('limit', 10)
        
        if not query:
            return Response({'error': 'Query requise'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Recherche multi-sources
        results = rechercher_sources_medicales(query)
        
        return Response({'results': results})
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def recherche_medicale(request):
    """Recherche médicale spécialisée"""
    if not verifier_api_key(request):
        return Response({'error': 'Clé API invalide'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        data = request.data
        query = data.get('query', '')
        contexte = data.get('contexte', {})
        
        if not query:
            return Response({'error': 'Query requise'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Enrichir la query avec le contexte médical
        query_enrichie = query
        if contexte:
            if contexte.get('symptomes'):
                query_enrichie += f" {' '.join(contexte['symptomes'])}"
            if contexte.get('diagnostic'):
                query_enrichie += f" {contexte['diagnostic']}"
        
        results = rechercher_sources_medicales(query_enrichie)
        
        return Response({'results': results})
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def generer_reponse(request):
    """Génération de réponse IA avec sources"""
    if not verifier_api_key(request):
        return Response({'error': 'Clé API invalide'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        data = request.data
        question = data.get('question', '')
        contexte = data.get('contexte', {})
        
        if not question:
            return Response({'error': 'Question requise'}, status=status.HTTP_400_BAD_REQUEST)
        
        start_time = time.time()
        
        # Rechercher des sources pertinentes
        sources = rechercher_sources_medicales(question, contexte)
        
        # Générer une réponse basée sur les sources (simulation)
        reponse = generer_reponse_basique(question, sources, contexte)
        
        temps_generation = time.time() - start_time
        
        return Response({
            'question': question,
            'reponse': reponse,
            'sources': sources,
            'confiance': 0.85,
            'temps_generation': temps_generation,
            'contexte': contexte
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

def generer_reponse_basique(question, sources, contexte):
    """Génère une réponse basée sur les sources disponibles"""
    if not sources:
        return "Je n'ai pas trouvé d'informations médicales pertinentes pour répondre à votre question. Veuillez consulter un professionnel de santé."
    
    # Extraire les snippets des sources
    snippets = [source['snippet'] for source in sources[:3]]
    
    # Générer une réponse structurée
    reponse = f"Basé sur les sources médicales disponibles, voici une réponse à votre question:\n\n"
    
    for i, snippet in enumerate(snippets, 1):
        reponse += f"{i}. {snippet}\n\n"
    
    reponse += "\nSources consultées:\n"
    for source in sources[:3]:
        reponse += f"- {source['titre']} ({source['source']})\n"
    
    reponse += "\nNote: Cette réponse est générée automatiquement et ne remplace pas un avis médical professionnel."
    
    return reponse

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def analyser_symptomes(request):
    """Analyse des symptômes"""
    if not verifier_api_key(request):
        return Response({'error': 'Clé API invalide'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        data = request.data
        symptomes = data.get('symptomes', [])
        patient_info = data.get('patient_info', {})
        
        if not symptomes:
            return Response({'error': 'Symptômes requis'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Analyse basique des symptômes (simulation)
        diagnostic_possibles = []
        
        # Mots-clés médicaux pour les symptômes
        symptom_keywords = {
            'fièvre': ['infection', 'grippe', 'covid-19'],
            'toux': ['rhume', 'bronchite', 'pneumonie'],
            'mal de tête': ['migraine', 'tension', 'sinusite'],
            'fatigue': ['anémie', 'dépression', 'hypothyroïdie']
        }
        
        for symptome in symptomes:
            symptome_lower = symptome.lower()
            for key, conditions in symptom_keywords.items():
                if key in symptome_lower:
                    for condition in conditions:
                        diagnostic_possibles.append({
                            'condition': condition,
                            'probabilite': 0.3,
                            'symptomes_associes': [symptome],
                            'recommandations': ['Consulter un médecin', 'Repos', 'Hydratation']
                        })
        
        # Évaluer le niveau d'urgence
        urgence_keywords = ['douleur thoracique', 'difficulté respiratoire', 'perte de connaissance']
        urgence = any(keyword in ' '.join(symptomes).lower() for keyword in urgence_keywords)
        
        return Response({
            'diagnostic_possibles': diagnostic_possibles[:5],
            'urgence': urgence,
            'confiance': 0.7
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def suggerer_traitements(request):
    """Suggestion de traitements"""
    if not verifier_api_key(request):
        return Response({'error': 'Clé API invalide'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        data = request.data
        diagnostic = data.get('diagnostic', '')
        patient_info = data.get('patient_info', {})
        
        if not diagnostic:
            return Response({'error': 'Diagnostic requis'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Suggestions basiques (simulation)
        traitements = []
        alternatives = []
        
        # Traitements communs selon le diagnostic
        if 'infection' in diagnostic.lower():
            traitements.append({
                'nom': 'Antibiotiques',
                'type': 'Médicament',
                'description': 'Traitement antibiotique selon le type d\'infection',
                'posologie': 'Selon prescription médicale',
                'contre_indications': 'Allergies connues',
                'efficacite': 0.8
            })
            alternatives.append({
                'nom': 'Thérapie naturelle',
                'description': 'Approches complémentaires',
                'avantages': 'Moins d\'effets secondaires'
            })
        
        return Response({
            'traitements': traitements,
            'alternatives': alternatives
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def verifier_interactions(request):
    """Vérification des interactions médicamenteuses"""
    if not verifier_api_key(request):
        return Response({'error': 'Clé API invalide'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        data = request.data
        medicaments = data.get('medicaments', [])
        
        if not medicaments:
            return Response({'error': 'Médicaments requis'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Vérification basique des interactions (simulation)
        interactions = []
        
        # Exemples d'interactions connues
        interaction_database = {
            'warfarine': ['aspirine', 'ibuprofene'],
            'digoxine': ['amiodarone', 'verapamil'],
            'statines': ['fibrates', 'niacine']
        }
        
        for i, med1 in enumerate(medicaments):
            for j, med2 in enumerate(medicaments[i+1:], i+1):
                med1_lower = med1.lower()
                med2_lower = med2.lower()
                
                for med_key, interactants in interaction_database.items():
                    if med_key in med1_lower and any(interactant in med2_lower for interactant in interactants):
                        interactions.append({
                            'medicament1': med1,
                            'medicament2': med2,
                            'niveau': 'moderee',
                            'description': f'Interaction potentielle entre {med1} et {med2}',
                            'recommandations': ['Surveillance accrue', 'Ajustement posologique possible']
                        })
        
        return Response({
            'interactions': interactions,
            'alternatives_suggeres': []
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def chat_medical(request):
    """Chatbot médical conversationnel"""
    if not verifier_api_key(request):
        return Response({'error': 'Clé API invalide'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        data = request.data
        message = data.get('message', '')
        conversation_id = data.get('conversation_id')
        contexte = data.get('contexte', {})
        
        if not message:
            return Response({'error': 'Message requis'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Générer un ID de conversation si nécessaire
        if not conversation_id:
            conversation_id = hashlib.md5(f"{message}_{datetime.now()}".encode()).hexdigest()[:16]
        
        # Analyser le message pour déterminer le niveau d'urgence
        urgence_keywords = ['urgence', 'douleur intense', 'difficulté respirer', 'saignement', 'perte connaissance']
        niveau_urgence = 'aucun'
        consulter_medecin = False
        
        message_lower = message.lower()
        if any(keyword in message_lower for keyword in urgence_keywords):
            niveau_urgence = 'eleve'
            consulter_medecin = True
        elif 'médecin' in message_lower or 'docteur' in message_lower:
            niveau_urgence = 'modere'
            consulter_medecin = True
        
        # Générer une réponse
        if niveau_urgence == 'eleve':
            reponse = "URGENCE : Veuillez contacter immédiatement les services d'urgence ou composer le 15. Ne tardez pas à consulter un professionnel de santé."
            suggestions = ['Appeler le 15', 'Se rendre aux urgences', 'Ne pas prendre de médicament sans avis médical']
        else:
            # Rechercher des informations pertinentes
            sources = rechercher_sources_medicales(message, contexte)
            reponse = generer_reponse_basique(message, sources, contexte)
            suggestions = ['Consulter un médecin', 'Prendre rendez-vous', 'Surveiller les symptômes']
        
        return Response({
            'reponse': reponse,
            'conversation_id': conversation_id,
            'suggestions': suggestions,
            'questions_suivantes': ['Avez-vous d\'autres symptômes?', 'Depuis quand ressentez-vous cela?'],
            'niveau_urgence': niveau_urgence,
            'consulter_medecin': consulter_medecin
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def configurer_service(request):
    """Configuration du service IA"""
    if not verifier_api_key(request):
        return Response({'error': 'Clé API invalide'}, status=status.HTTP_401_UNAUTHORIZED)
    
    try:
        config = request.data
        
        # Appliquer la configuration
        # Note: En production, sauvegarder la configuration en base de données
        
        return Response({
            'success': True,
            'message': 'Configuration mise à jour avec succès'
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
