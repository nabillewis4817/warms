import html
import logging
import re
import requests
from urllib.parse import parse_qs, unquote, urlparse
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.conf import settings
from django.utils import timezone
from django.db.models import Q
import uuid
import json

from assistant_ia.services_llm import reponse_ia as generer_reponse_riche
from patients.models import Patient

from .models import (
    ConversationIA, MessageIA, RechercheIA,
    AnalyseMedicale, DocumentOCR, PreferenceIA
)
from .serializers import (
    ConversationIASerializer, MessageIASerializer,
    RechercheIASerializer, AnalyseMedicaleSerializer,
    DocumentOCRSerializer, PreferenceIASerializer
)

# Détection rapide d'urgence dentaire, appliquée avant tout moteur de
# réponse (Claude ou repli local) pour ne jamais laisser un message
# urgent attendre une génération de texte plus lente.
REGLES_CHAT_URGENCE = [
    'urgence', 'douleur intense', 'douleur insupportable', 'saignement',
    'gonflement', 'dent cassée', 'dent cassee', 'accident', 'choc',
]


logger = logging.getLogger(__name__)


def effectuer_recherche_google(query: str, limite: int = 10) -> list:
    """Recherche web réelle via l'API Google Custom Search."""
    if not settings.GOOGLE_API_KEY or not settings.GOOGLE_CSE_ID:
        return []

    try:
        reponse = requests.get(
            'https://www.googleapis.com/customsearch/v1',
            params={
                'key': settings.GOOGLE_API_KEY,
                'cx': settings.GOOGLE_CSE_ID,
                'q': query,
                'num': min(limite, 10),
            },
            timeout=10,
        )
        reponse.raise_for_status()
        items = reponse.json().get('items', [])
    except (requests.RequestException, ValueError) as exc:
        # Échec silencieux côté utilisateur (liste vide) mais loggé ici :
        # sans ce log, une mauvaise configuration du projet Google Cloud
        # (ex. "Custom Search JSON API" non activée, quota dépassé) est
        # indissociable d'une recherche qui n'a simplement aucun résultat.
        logger.warning("Recherche Google Custom Search indisponible: %s", exc)
        return []

    resultats = []
    for i, item in enumerate(items):
        resultats.append({
            'title': item.get('title', 'Sans titre'),
            'summary': item.get('snippet', ''),
            'source': item.get('displayLink', 'web'),
            'url': item.get('link', ''),
            'date': '',
            'relevance': round(1.0 - (i * 0.07), 2),
        })
    return resultats


def _nettoyer_html(texte_html: str) -> str:
    """Retire les balises HTML restantes et décode les entités (&#x27;, &amp;...)."""
    return html.unescape(re.sub(r'<[^>]+>', '', texte_html)).strip()


def _url_reelle_duckduckgo(lien_ddg: str) -> str:
    """DuckDuckGo redirige via `/l/?uddg=<url encodée>` : on extrait la
    vraie destination plutôt que ce lien de redirection interne."""
    params = parse_qs(urlparse(lien_ddg).query)
    cible = params.get('uddg', [''])[0]
    return unquote(cible) if cible else lien_ddg


def effectuer_recherche_duckduckgo(query: str, limite: int = 10) -> list:
    """Recherche web réelle via la page HTML publique de DuckDuckGo —
    aucune clé API ni compte de facturation requis, à la différence de
    Google Custom Search (utilisé par défaut si GOOGLE_API_KEY est
    configurée, voir [effectuer_recherche_google])."""
    try:
        reponse = requests.get(
            'https://html.duckduckgo.com/html/',
            params={'q': query},
            headers={'User-Agent': 'Mozilla/5.0 (compatible; WARMS dental cabinet assistant)'},
            timeout=10,
        )
        reponse.raise_for_status()
    except requests.RequestException:
        return []

    page = reponse.text
    titres_liens = re.findall(
        r'<a rel="nofollow" class="result__a" href="([^"]+)">(.*?)</a>',
        page, re.DOTALL,
    )
    snippets = re.findall(
        r'<a class="result__snippet"[^>]*>(.*?)</a>',
        page, re.DOTALL,
    )

    resultats = []
    for i, (lien, titre_brut) in enumerate(titres_liens[:limite]):
        url = _url_reelle_duckduckgo(lien)
        snippet = _nettoyer_html(snippets[i]) if i < len(snippets) else ''
        resultats.append({
            'title': _nettoyer_html(titre_brut),
            'summary': snippet,
            'source': urlparse(url).netloc or 'web',
            'url': url,
            'date': '',
            'relevance': round(1.0 - (i * 0.07), 2),
        })
    return resultats


class ConversationIAViewSet(viewsets.ModelViewSet):
    """ViewSet pour les conversations IA - partagé Web/Mobile"""
    serializer_class = ConversationIASerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = ConversationIA.objects.filter(utilisateur=self.request.user)
        if self.action == 'list':
            queryset = queryset.filter(
                plateforme=self.request.query_params.get('plateforme', 'web')
            )
        return queryset
    
    def create(self, request, *args, **kwargs):
        plateforme = request.data.get('plateforme', 'web')
        conversation_id = str(uuid.uuid4())[:16]
        
        conversation = ConversationIA.objects.create(
            id=conversation_id,
            utilisateur=request.user,
            plateforme=plateforme,
            contexte=request.data.get('contexte', {})
        )
        
        serializer = self.get_serializer(conversation)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['post'])
    def ajouter_message(self, request, pk=None):
        """Ajouter un message à la conversation"""
        conversation = self.get_object()
        
        message_data = {
            'conversation': conversation,
            'contenu': request.data.get('contenu'),
            'type_message': request.data.get('type_message', 'user'),
            'metadonnees': request.data.get('metadonnees', {})
        }
        
        message = MessageIA.objects.create(**message_data)
        
        # Si c'est un message utilisateur, générer une réponse IA
        if message.type_message == 'user':
            resultat_ia = self.generer_reponse_ia(
                message.contenu,
                conversation.contexte,
                conversation.utilisateur,
            )

            message_ia = MessageIA.objects.create(
                conversation=conversation,
                contenu=resultat_ia['reponse'],
                type_message='ia',
                metadonnees=resultat_ia.get('metadonnees', {})
            )
            
            conversation.modifie_le = timezone.now()
            conversation.save()
            
            return Response({
                'message_user': MessageIASerializer(message).data,
                'message_ia': MessageIASerializer(message_ia).data
            })
        
        return Response(MessageIASerializer(message).data)
    
    def generer_reponse_ia(self, message, contexte, utilisateur):
        """Génère une réponse IA en réutilisant le même moteur que
        l'assistant web (`assistant_ia.services_llm.reponse_ia`) : Claude
        si une clé est configurée, sinon un repli local qui reste
        spécifique à la question posée et enrichi des données réelles du
        patient (allergies, rendez-vous, consultations) plutôt que les six
        réponses figées de [generer_reponse_regles] utilisées avant."""
        texte = (message or '').lower()
        if any(mot in texte for mot in REGLES_CHAT_URGENCE):
            return {
                'reponse': (
                    "Cela ressemble à une urgence dentaire. Contactez "
                    "directement le cabinet ou rendez-vous aux urgences "
                    "dentaires les plus proches sans attendre."
                ),
                'metadonnees': {'niveau_urgence': 'critique', 'confidence': 0.6},
            }

        patient = Patient.objects.filter(user=utilisateur).first()
        contexte_str = contexte if isinstance(contexte, str) else json.dumps(contexte or {}, ensure_ascii=False)
        reponse = generer_reponse_riche(message, contexte_str, patient.id if patient else None)
        return {
            'reponse': reponse,
            'metadonnees': {'niveau_urgence': 'aucun', 'confidence': 0.75},
        }

class RechercheIAViewSet(viewsets.ModelViewSet):
    """ViewSet pour les recherches IA - partagé Web/Mobile"""
    serializer_class = RechercheIASerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return RechercheIA.objects.filter(
            utilisateur=self.request.user,
            plateforme=self.request.query_params.get('plateforme', 'web')
        )
    
    def create(self, request, *args, **kwargs):
        """Effectuer une recherche web réelle (Google Custom Search) et
        l'enregistrer dans l'historique de l'utilisateur.

        DuckDuckGo sans clé a été testé en alternative gratuite mais
        bloque les requêtes automatisées (anti-bot, HTTP 202 sans
        résultats) — pas fiable pour un usage serveur réel. La fonction
        [effectuer_recherche_duckduckgo] reste disponible si une solution
        de contournement est trouvée plus tard."""
        query = request.data.get('query')
        plateforme = request.data.get('plateforme', 'web')
        contexte = request.data.get('contexte', {})

        if not query:
            return Response({'error': 'query requise'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            resultats = effectuer_recherche_google(query)
            if not resultats:
                # Repli gratuit si Google Custom Search est mal configuré
                # côté Google Cloud (clé/CSE invalide, API non activée,
                # quota dépassé) ou indisponible.
                resultats = effectuer_recherche_duckduckgo(query)

            RechercheIA.objects.create(
                utilisateur=request.user,
                query=query,
                plateforme=plateforme,
                resultat={'resultats': resultats},
                contexte=contexte,
            )

            return Response({
                'query': query,
                'resultats': resultats,
                # Permet au frontend de distinguer "aucun résultat pour
                # cette recherche" de "le service de recherche est
                # indisponible en ce moment" plutôt que d'afficher la même
                # liste vide silencieuse dans les deux cas.
                'service_indisponible': not resultats,
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class AnalyseMedicaleViewSet(viewsets.ModelViewSet):
    """ViewSet pour les analyses médicales IA - partagé Web/Mobile"""
    serializer_class = AnalyseMedicaleSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return AnalyseMedicale.objects.filter(
            utilisateur=self.request.user,
            plateforme=self.request.query_params.get('plateforme', 'web')
        )
    
    @action(detail=False, methods=['post'])
    def analyser_symptomes(self, request):
        """Analyser les symptômes avec IA"""
        from ia_avancee.views import analyser_symptomes as ia_analyser_symptomes
        
        symptomes = request.data.get('symptomes', [])
        patient_info = request.data.get('patient_info', {})
        plateforme = request.data.get('plateforme', 'web')
        
        try:
            request_data = {'symptomes': symptomes, 'patient_info': patient_info}
            
            from django.test import RequestFactory
            factory = RequestFactory()
            request_ia = factory.post('/ia/analyser-symptomes/', request_data, format='json')
            request_ia.user = request.user
            
            response = ia_analyser_symptomes(request_ia)
            
            if response.status_code == 200:
                analyse = AnalyseMedicale.objects.create(
                    utilisateur=request.user,
                    patient_id=patient_info.get('id'),
                    type_analyse='symptomes',
                    donnees_entree={'symptomes': symptomes, 'patient_info': patient_info},
                    resultat=response.data,
                    confiance=response.data.get('confiance', 0.7),
                    plateforme=plateforme
                )
                
                serializer = self.get_serializer(analyse)
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            else:
                return Response(response.data, status=response.status_code)
                
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class DocumentOCRViewSet(viewsets.ModelViewSet):
    """ViewSet pour les documents OCR - partagé Web/Mobile"""
    serializer_class = DocumentOCRSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return DocumentOCR.objects.filter(
            utilisateur=self.request.user,
            plateforme=self.request.query_params.get('plateforme', 'web')
        )
    
    def create(self, request, *args, **kwargs):
        """Traiter un document avec OCR"""
        from ocr.views import extract_text as ocr_extract_text
        
        if 'image' not in request.FILES:
            return Response({'error': 'Aucune image fournie'}, status=status.HTTP_400_BAD_REQUEST)
        
        plateforme = request.data.get('plateforme', 'web')
        metadonnees = request.data.get('metadonnees', {})
        
        try:
            # Utiliser le service OCR existant
            from django.test import RequestFactory
            factory = RequestFactory()
            request_ocr = factory.post('/ocr/extract-text/', request.FILES, format='multipart')
            request_ocr.user = request.user
            
            response = ocr_extract_text(request_ocr)
            
            if response.status_code == 200:
                document = DocumentOCR.objects.create(
                    utilisateur=request.user,
                    fichier_original=request.FILES['image'],
                    texte_extrait=response.data.get('text', ''),
                    metadonnees={**metadonnees, 'ocr_result': response.data},
                    confiance=response.data.get('confidence', 0.0),
                    plateforme=plateforme
                )
                
                serializer = self.get_serializer(document)
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            else:
                return Response(response.data, status=response.status_code)
                
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET', 'POST', 'PUT'])
@permission_classes([IsAuthenticated])
def preferences_ia(request):
    """Gérer les préférences IA par utilisateur et plateforme"""
    plateforme = request.query_params.get('plateforme', 'web')
    
    if request.method == 'GET':
        try:
            preferences, created = PreferenceIA.objects.get_or_create(
                utilisateur=request.user,
                plateforme=plateforme,
                defaults={
                    'langue': 'fr',
                    'voix_activee': False,
                    'notifications_ia': True,
                    'mode_expert': False,
                    'sauvegarder_conversations': True
                }
            )
            
            serializer = PreferenceIASerializer(preferences)
            return Response(serializer.data)
            
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    elif request.method in ['POST', 'PUT']:
        try:
            preferences, created = PreferenceIA.objects.get_or_create(
                utilisateur=request.user,
                plateforme=plateforme
            )
            
            # Mettre à jour les préférences
            for field in ['langue', 'voix_activee', 'notifications_ia', 'mode_expert', 'sauvegarder_conversations']:
                if field in request.data:
                    setattr(preferences, field, request.data[field])
            
            preferences.save()
            
            serializer = PreferenceIASerializer(preferences)
            return Response(serializer.data)
            
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def statistiques_ia(request):
    """Statistiques d'utilisation IA par plateforme"""
    plateforme = request.query_params.get('plateforme', 'web')
    
    try:
        stats = {
            'conversations_total': ConversationIA.objects.filter(
                utilisateur=request.user, 
                plateforme=plateforme
            ).count(),
            'messages_total': MessageIA.objects.filter(
                conversation__utilisateur=request.user,
                conversation__plateforme=plateforme
            ).count(),
            'recherches_total': RechercheIA.objects.filter(
                utilisateur=request.user,
                plateforme=plateforme
            ).count(),
            'analyses_medicales': AnalyseMedicale.objects.filter(
                utilisateur=request.user,
                plateforme=plateforme
            ).count(),
            'documents_ocr': DocumentOCR.objects.filter(
                utilisateur=request.user,
                plateforme=plateforme
            ).count()
        }
        
        return Response(stats)
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
