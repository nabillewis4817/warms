from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.http import HttpResponse
from django.db.models import Q, Avg, Count, F
from django.utils import timezone
from django.db.models.functions import Trunc
import csv
from datetime import datetime, timedelta

from .models import Avis, StatistiquesAvis, MotifSignalement
from .serializers import (
    AvisSerializer, AvisCreateSerializer, AvisUpdateSerializer,
    AvisListSerializer, AvisModerationSerializer, AvisReponseSerializer,
    StatistiquesAvisSerializer, MotifSignalementSerializer
)


class AvisViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour la gestion des avis
    """
    
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = Avis.objects.select_related('patient', 'modere_par', 'reponse_par').all()
        
        # Filtrage par type d'avis
        type_avis = self.request.query_params.get('type_avis')
        if type_avis:
            queryset = queryset.filter(type_avis=type_avis)
        
        # Filtrage par statut
        statut = self.request.query_params.get('statut')
        if statut:
            queryset = queryset.filter(statut=statut)
        
        # Filtrage par note
        note_min = self.request.query_params.get('note_min')
        note_max = self.request.query_params.get('note_max')
        if note_min:
            queryset = queryset.filter(note__gte=note_min)
        if note_max:
            queryset = queryset.filter(note__lte=note_max)
        
        # Filtrage par période
        date_debut = self.request.query_params.get('date_debut')
        date_fin = self.request.query_params.get('date_fin')
        if date_debut:
            queryset = queryset.filter(cree_le__date__gte=date_debut)
        if date_fin:
            queryset = queryset.filter(cree_le__date__lte=date_fin)
        
        # Filtrage par patient
        patient_id = self.request.query_params.get('patient_id')
        if patient_id:
            queryset = queryset.filter(patient_id=patient_id)
        
        # Filtrage par recherche
        recherche = self.request.query_params.get('recherche')
        if recherche:
            queryset = queryset.filter(
                Q(titre__icontains=recherche) |
                Q(commentaire__icontains=recherche) |
                Q(patient__first_name__icontains=recherche) |
                Q(patient__last_name__icontains=recherche)
            )
        
        return queryset.order_by('-cree_le')
    
    def get_serializer_class(self):
        if self.action == 'list':
            return AvisListSerializer
        elif self.action == 'create':
            return AvisCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return AvisUpdateSerializer
        return AvisSerializer
    
    def perform_create(self, serializer):
        """Crée un avis — seuls les patients peuvent en soumettre."""
        from rest_framework.exceptions import PermissionDenied
        if getattr(self.request.user, 'role', '') != 'patient':
            raise PermissionDenied("Seuls les patients peuvent soumettre un avis.")
        serializer.save(patient=self.request.user)
    
    @action(detail=False, methods=['get'])
    def types(self, request):
        """Obtenir la liste des types d'avis disponibles"""
        types = [{'value': choice[0], 'label': choice[1]} for choice in Avis.TypeAvis.choices]
        return Response(types)
    
    @action(detail=False, methods=['get'])
    def statuts(self, request):
        """Obtenir la liste des statuts disponibles"""
        statuts = [{'value': choice[0], 'label': choice[1]} for choice in Avis.StatutAvis.choices]
        return Response(statuts)
    
    @action(detail=False, methods=['get'])
    def statistiques(self, request):
        """Obtenir les statistiques des avis"""
        stats = {
            'total_avis': Avis.objects.count(),
            'note_moyenne': Avis.objects.aggregate(moyenne=Avg('note'))['moyenne'] or 0,
            'par_type': {},
            'par_note': {},
            'par_statut': {},
            'avis_recents': Avis.objects.filter(
                cree_le__gte=timezone.now() - timedelta(days=30)
            ).count(),
            'avec_reponse': Avis.objects.exclude(reponse_personnel='').count(),
        }
        
        # Statistiques par type
        for type_avis in Avis.TypeAvis:
            stats['par_type'][type_avis.value] = {
                'count': Avis.objects.filter(type_avis=type_avis.value).count(),
                'avg_note': Avis.objects.filter(type_avis=type_avis.value).aggregate(
                    moyenne=Avg('note')
                )['moyenne'] or 0,
            }
        
        # Distribution des notes
        for note in range(1, 6):
            stats['par_note'][str(note)] = Avis.objects.filter(note=note).count()
        
        # Statistiques par statut
        for statut in Avis.StatutAvis:
            stats['par_statut'][statut.value] = Avis.objects.filter(statut=statut.value).count()
        
        return Response(stats)
    
    @action(detail=False, methods=['get'])
    def evolution(self, request):
        """Obtenir l'évolution des avis sur les 6 derniers mois"""
        six_mois = timezone.now() - timedelta(days=180)
        
        evolution = Avis.objects.filter(
            cree_le__gte=six_mois
        ).annotate(
            mois=Trunc('cree_le', 'month')
        ).values('mois').annotate(
            nombre_avis=Count('id'),
            note_moyenne=Avg('note')
        ).order_by('mois')
        
        return Response(list(evolution))
    
    @action(detail=False, methods=['post'])
    def exporter(self, request):
        """Exporter les avis en CSV"""
        queryset = self.get_queryset()
        
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="avis_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv"'
        
        writer = csv.writer(response)
        writer.writerow([
            'ID', 'Patient', 'Type', 'Note', 'Titre', 'Commentaire',
            'Statut', 'Date création', 'Date réponse', 'Nombre signalements'
        ])
        
        for avis in queryset:
            writer.writerow([
                avis.id,
                avis.patient_nom,
                avis.get_type_avis_display(),
                avis.note,
                avis.titre,
                avis.commentaire,
                avis.get_statut_display(),
                avis.cree_le.strftime('%Y-%m-%d %H:%M'),
                avis.date_reponse.strftime('%Y-%m-%d %H:%M') if avis.date_reponse else '',
                avis.nombre_signalements,
            ])
        
        return response
    
    @action(detail=True, methods=['post'])
    def signaler(self, request, pk=None):
        """Signaler un avis"""
        avis = self.get_object()
        
        if not avis.peut_etre_signale(request.user):
            return Response(
                {'error': 'Vous ne pouvez pas signaler cet avis'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if avis.signaler(request.user):
            return Response({
                'message': 'Avis signalé avec succès',
                'nombre_signalements': avis.nombre_signalements
            })
        else:
            return Response(
                {'error': 'Erreur lors du signalement'},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=True, methods=['post'])
    def repondre(self, request, pk=None):
        """Répondre à un avis"""
        avis = self.get_object()
        
        serializer = AvisReponseSerializer(
            avis,
            data=request.data,
            context={'request': request}
        )
        
        if serializer.is_valid():
            serializer.save()
            return Response({
                'message': 'Réponse enregistrée avec succès',
                'reponse': serializer.data
            })
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=True, methods=['post'])
    def moderer(self, request, pk=None):
        """Modérer un avis (réservé aux administrateurs)"""
        if not request.user.is_staff and not request.user.is_superuser:
            return Response(
                {'error': 'Permission refusée'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        avis = self.get_object()
        
        serializer = AvisModerationSerializer(
            avis,
            data=request.data,
            context={'request': request}
        )
        
        if serializer.is_valid():
            serializer.save(
                modere_par=request.user,
                date_moderation=timezone.now()
            )
            return Response({
                'message': 'Avis modéré avec succès',
                'avis': AvisSerializer(avis).data
            })
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['post'])
    def creer_donnees_test(self, request):
        """Crée des données de test pour les avis (développement uniquement)"""
        from django.contrib.auth import get_user_model
        User = get_user_model()
        
        try:
            # Récupérer des utilisateurs patients
            patients = User.objects.filter(role='patient')[:5]
            
            if not patients:
                return Response(
                    {'error': 'Aucun patient trouvé pour créer les avis de test'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            avis_test = [
                {
                    'type_avis': 'consultation',
                    'note': 5,
                    'titre': 'Excellente consultation',
                    'commentaire': 'Le dentiste a été très professionnel et attentif.',
                    'points_positifs': ['Professionnalisme', 'Écoute', 'Explication claire'],
                    'points_negatifs': [],
                    'suggestions': ['Continuer comme ça'],
                },
                {
                    'type_avis': 'accueil',
                    'note': 4,
                    'titre': 'Bon accueil',
                    'commentaire': 'La secrétaire a été très aimable et efficace.',
                    'points_positifs': ['Amabilité', 'Efficacité'],
                    'points_negatifs': ['Temps d\'attente un peu long'],
                    'suggestions': ['Optimiser les horaires'],
                },
                {
                    'type_avis': 'installations',
                    'note': 4,
                    'titre': 'Installations modernes',
                    'commentaire': 'Le matériel est moderne et bien entretenu.',
                    'points_positifs': ['Propreté', 'Matériel moderne'],
                    'points_negatifs': ['Manque de places de parking'],
                    'suggestions': ['Aménager plus de parking'],
                },
                {
                    'type_avis': 'traitement',
                    'note': 5,
                    'titre': 'Traitement parfait',
                    'commentaire:': 'Le traitement s\'est très bien passé, sans douleur.',
                    'points_positifs': ['Sans douleur', 'Rapide', 'Efficace'],
                    'points_negatifs': [],
                    'suggestions': [],
                },
                {
                    'type_avis': 'personnel',
                    'note': 5,
                    'titre': 'Personnel compétent',
                    'commentaire': 'Toute l\'équipe est très compétente et sympathique.',
                    'points_positifs': ['Compétence', 'Sympathie', 'Travail d\'équipe'],
                    'points_negatifs': [],
                    'suggestions': [],
                },
            ]
            
            avis_crees = []
            for i, avis_data in enumerate(avis_test):
                serializer = AvisCreateSerializer(
                    data=avis_data,
                    context={'request': request}
                )
                if serializer.is_valid():
                    avis = serializer.save(patient=patients[i % len(patients)])
                    avis_crees.append(AvisSerializer(avis).data)
            
            return Response({
                'message': f'{len(avis_crees)} avis de test créés avec succès',
                'avis': avis_crees
            })
            
        except Exception as e:
            return Response(
                {'error': f'Erreur lors de la création des avis de test: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class StatistiquesAvisViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet pour les statistiques des avis
    """
    
    queryset = StatistiquesAvis.objects.all()
    serializer_class = StatistiquesAvisSerializer
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['post'])
    def generer_statistiques(self, request):
        """Génère les statistiques pour la période actuelle"""
        try:
            periode = timezone.now().date()
            
            # Générer pour chaque type d'avis
            for type_avis in Avis.TypeAvis:
                avis_du_mois = Avis.objects.filter(
                    cree_le__date=periode,
                    type_avis=type_avis.value
                )
                
                if avis_du_mois.exists():
                    # Calculer la distribution des notes
                    distribution = {str(note): 0 for note in range(1, 6)}
                    for avis in avis_du_mois:
                        distribution[str(avis.note)] += 1
                    
                    StatistiquesAvis.objects.update_or_create(
                        periode=periode,
                        type_avis=type_avis.value,
                        defaults={
                            'nombre_avis': avis_du_mois.count(),
                            'note_moyenne': avis_du_mois.aggregate(
                                moyenne=Avg('note')
                            )['moyenne'] or 0,
                            'note_distribution': distribution,
                        }
                    )
            
            return Response({
                'message': 'Statistiques générées avec succès',
                'periode': periode.strftime('%Y-%m-%d')
            })
            
        except Exception as e:
            return Response(
                {'error': f'Erreur lors de la génération des statistiques: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class MotifSignalementViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour les motifs de signalement
    """
    
    queryset = MotifSignalement.objects.filter(actif=True)
    serializer_class = MotifSignalementSerializer
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            # Seuls les administrateurs peuvent gérer les motifs
            if self.request.user.is_staff or self.request.user.is_superuser:
                return MotifSignalementSerializer
            else:
                return MotifSignalementSerializer
        return MotifSignalementSerializer
