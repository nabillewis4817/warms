from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.utils import timezone
from django.db.models import Q
import uuid
import json

from .models import (
    ConversationIA, MessageIA, RechercheIA, 
    AnalyseMedicale, DocumentOCR, PreferenceIA
)
from .serializers import (
    ConversationIASerializer, MessageIASerializer,
    RechercheIASerializer, AnalyseMedicaleSerializer,
    DocumentOCRSerializer, PreferenceIASerializer
)

class ConversationIAViewSet(viewsets.ModelViewSet):
    """ViewSet pour les conversations IA - partagé Web/Mobile"""
    serializer_class = ConversationIASerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return ConversationIA.objects.filter(
            utilisateur=self.request.user,
            plateforme=self.request.query_params.get('plateforme', 'web')
        )
    
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
            'conversation': conversation.id,
            'contenu': request.data.get('contenu'),
            'type_message': request.data.get('type_message', 'user'),
            'metadonnees': request.data.get('metadonnees', {})
        }
        
        message = MessageIA.objects.create(**message_data)
        
        # Si c'est un message utilisateur, générer une réponse IA
        if message.type_message == 'user':
            reponse_ia = self.generer_reponse_ia(
                message.contenu, 
                conversation.contexte,
                conversation.plateforme
            )
            
            message_ia = MessageIA.objects.create(
                conversation=conversation,
                contenu=reponse_ia['reponse'],
                type_message='ia',
                metadonnees=reponse_ia.get('metadonnees', {})
            )
            
            conversation.modifie_le = timezone.now()
            conversation.save()
            
            return Response({
                'message_user': MessageIASerializer(message).data,
                'message_ia': MessageIASerializer(message_ia).data
            })
        
        return Response(MessageIASerializer(message).data)
    
    def generer_reponse_ia(self, message, contexte, plateforme):
        """Générer une réponse IA (intégration avec service IA existant)"""
        # Import du service IA avancé
        from ia_avancee.views import generer_reponse as ia_generer_reponse
        
        try:
            # Utiliser le service IA existant
            request_data = {
                'question': message,
                'contexte': contexte
            }
            
            # Simuler une requête pour le service IA
            from django.test import RequestFactory
            factory = RequestFactory()
            request = factory.post('/ia/generer-reponse/', request_data, format='json')
            request.user = self.request.user
            
            response = ia_generer_reponse(request)
            
            if response.status_code == 200:
                return response.data
            else:
                return {
                    'reponse': 'Je ne peux pas répondre pour le moment. Veuillez réessayer.',
                    'metadonnees': {'erreur': 'Service IA indisponible'}
                }
        except Exception as e:
            return {
                'reponse': f'Erreur: {str(e)}',
                'metadonnees': {'erreur': str(e)}
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
        """Effectuer une recherche IA"""
        from ia_avancee.views import recherche_web as ia_recherche_web
        
        query = request.data.get('query')
        plateforme = request.data.get('plateforme', 'web')
        contexte = request.data.get('contexte', {})
        
        try:
            # Utiliser le service de recherche IA existant
            request_data = {'query': query, 'contexte': contexte}
            
            from django.test import RequestFactory
            factory = RequestFactory()
            request_ia = factory.post('/ia/recherche-web/', request_data, format='json')
            request_ia.user = request.user
            
            response = ia_recherche_web(request_ia)
            
            if response.status_code == 200:
                recherche = RechercheIA.objects.create(
                    utilisateur=request.user,
                    query=query,
                    plateforme=plateforme,
                    resultat=response.data,
                    contexte=contexte
                )
                
                serializer = self.get_serializer(recherche)
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            else:
                return Response(response.data, status=response.status_code)
                
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
