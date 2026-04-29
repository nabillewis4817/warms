from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.http import HttpResponse
from django.db.models import Q
from django.utils import timezone
import csv
from datetime import datetime, timedelta

from .models_personnel import Personnel, HistoriqueStatut, Presence
from .serializers_personnel import (
    PersonnelSerializer, PersonnelCreateSerializer, PersonnelUpdateSerializer,
    PersonnelListSerializer, HistoriqueStatutSerializer, PresenceSerializer
)


class PersonnelViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour la gestion du personnel médical
    """
    
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = Personnel.objects.select_related('utilisateur').all()
        
        # Filtrage par recherche
        recherche = self.request.query_params.get('recherche', '')
        if recherche:
            queryset = queryset.filter(
                Q(utilisateur__first_name__icontains=recherche) |
                Q(utilisateur__last_name__icontains=recherche) |
                Q(utilisateur__email__icontains=recherche) |
                Q(matricule__icontains=recherche) |
                Q(specialite__icontains=recherche)
            )
        
        # Filtrage par rôle
        role = self.request.query_params.get('role')
        if role:
            queryset = queryset.filter(utilisateur__role=role)
        
        # Filtrage par service
        service = self.request.query_params.get('service')
        if service:
            queryset = queryset.filter(service=service)
        
        # Filtrage par statut
        statut = self.request.query_params.get('statut')
        if statut:
            queryset = queryset.filter(statut=statut)
        
        return queryset.order_by('-cree_le')
    
    def get_serializer_class(self):
        if self.action == 'list':
            return PersonnelListSerializer
        elif self.action == 'create':
            return PersonnelCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return PersonnelUpdateSerializer
        return PersonnelSerializer
    
    @action(detail=False, methods=['get'])
    def roles(self, request):
        """Obtenir la liste des rôles disponibles"""
        from django.contrib.auth import get_user_model
        User = get_user_model()
        
        roles = [{'value': choice[0], 'label': choice[1]} for choice in User.Role.choices]
        return Response(roles)
    
    @action(detail=False, methods=['get'])
    def services(self, request):
        """Obtenir la liste des services disponibles"""
        services = [
            {'value': choice[0], 'label': choice[1]}
            for choice in Personnel._meta.get_field('service').choices
        ]
        return Response(services)
    
    @action(detail=False, methods=['get'])
    def specialites(self, request):
        """Obtenir la liste des spécialités disponibles"""
        specialites = [
            'Implantologie',
            'Orthodontie',
            'Pédiatrie',
            'Parodontologie',
            'Endodontie',
            'Prothèse dentaire',
            'Chirurgie orale',
            'Médecine bucco-dentaire'
        ]
        return Response(specialites)
    
    @action(detail=False, methods=['get'])
    def statistiques(self, request):
        """Obtenir les statistiques du personnel"""
        from django.contrib.auth import get_user_model
        User = get_user_model()
        
        stats = {
            'total_personnel': Personnel.objects.count(),
            'par_role': {},
            'par_service': {},
            'par_statut': {},
            'nouvellement_embauches': Personnel.objects.filter(
                date_embauche__gte=timezone.now().date() - timedelta(days=30)
            ).count(),
            'actifs_ce_jour': Personnel.objects.filter(
                statut='actif'
            ).count(),
        }
        
        # Statistiques par rôle
        for role in User.Role:
            stats['par_role'][role.value] = Personnel.objects.filter(
                utilisateur__role=role.value
            ).count()
        
        # Statistiques par service
        for service_choice in Personnel._meta.get_field('service').choices:
            stats['par_service'][service_choice[0]] = Personnel.objects.filter(
                service=service_choice[0]
            ).count()
        
        # Statistiques par statut
        for statut in Personnel.Statut:
            stats['par_statut'][statut.value] = Personnel.objects.filter(
                statut=statut.value
            ).count()
        
        return Response(stats)
    
    @action(detail=False, methods=['post'])
    def exporter(self, request):
        """Exporter la liste du personnel en CSV"""
        queryset = self.get_queryset()
        
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="personnel_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv"'
        
        writer = csv.writer(response)
        writer.writerow([
            'Matricule', 'Nom', 'Prénom', 'Email', 'Téléphone', 'Rôle',
            'Service', 'Spécialité', 'Statut', 'Date d\'embauche', 'Ancienneté'
        ])
        
        for personnel in queryset:
            writer.writerow([
                personnel.matricule,
                personnel.utilisateur.last_name,
                personnel.utilisateur.first_name,
                personnel.utilisateur.email,
                personnel.telephone,
                personnel.utilisateur.role,
                personnel.get_service_display(),
                personnel.specialite,
                personnel.get_statut_display(),
                personnel.date_embauche,
                personnel.anciennete
            ])
        
        return response
    
    @action(detail=True, methods=['post'])
    def changer_statut(self, request, pk=None):
        """Changer le statut d'un membre du personnel"""
        personnel = self.get_object()
        nouveau_statut = request.data.get('statut')
        raison = request.data.get('raison', '')
        
        if not nouveau_statut:
            return Response(
                {'error': 'Le nouveau statut est requis'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Enregistrer l'ancien statut
        ancien_statut = personnel.statut
        
        # Mettre à jour le statut
        personnel.statut = nouveau_statut
        personnel.save()
        
        # Créer l'historique
        HistoriqueStatut.objects.create(
            personnel=personnel,
            ancien_statut=ancien_statut,
            nouveau_statut=nouveau_statut,
            raison=raison,
            modifie_par=request.user
        )
        
        return Response({
            'message': 'Statut mis à jour avec succès',
            'ancien_statut': ancien_statut,
            'nouveau_statut': nouveau_statut
        })
    
    @action(detail=True, methods=['get'])
    def historique_statuts(self, request, pk=None):
        """Obtenir l'historique des changements de statut"""
        personnel = self.get_object()
        historique = HistoriqueStatut.objects.filter(personnel=personnel)
        
        serializer = HistoriqueStatutSerializer(historique, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get', 'post'])
    def presence(self, request, pk=None):
        """Gérer la présence du personnel"""
        personnel = self.get_object()
        
        if request.method == 'GET':
            # Obtenir la présence du mois en cours
            debut_mois = timezone.now().date().replace(day=1)
            presences = Presence.objects.filter(
                personnel=personnel,
                date__gte=debut_mois
            ).order_by('-date')
            
            serializer = PresenceSerializer(presences, many=True)
            return Response(serializer.data)
        
        elif request.method == 'POST':
            # Enregistrer une présence
            date_str = request.data.get('date')
            heure_arrivee = request.data.get('heure_arrivee')
            heure_depart = request.data.get('heure_depart')
            statut = request.data.get('statut', 'present')
            notes = request.data.get('notes', '')
            
            if not date_str:
                return Response(
                    {'error': 'La date est requise'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            try:
                date_obj = datetime.strptime(date_str, '%Y-%m-%d').date()
            except ValueError:
                return Response(
                    {'error': 'Format de date invalide. Utilisez YYYY-MM-DD'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            presence, created = Presence.objects.update_or_create(
                personnel=personnel,
                date=date_obj,
                defaults={
                    'heure_arrivee': heure_arrivee,
                    'heure_depart': heure_depart,
                    'statut': statut,
                    'notes': notes
                }
            )
            
            serializer = PresenceSerializer(presence)
            return Response(
                serializer.data,
                status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
            )
    
    @action(detail=False, methods=['post'])
    def creer_donnees_test(self, request):
        """Crée des données de test pour le personnel (développement uniquement)"""
        from django.contrib.auth import get_user_model
        User = get_user_model()
        
        try:
            # Récupérer des utilisateurs existants
            utilisateurs = User.objects.filter(
                role__in=['chirurgien_dentiste', 'secretaire', 'infirmiere']
            )[:5]
            
            if not utilisateurs:
                return Response(
                    {'error': 'Aucun utilisateur approprié trouvé pour créer le personnel de test'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            personnel_test = []
            services = ['chirurgie_generale', 'orthodontie', 'pediatrie', 'administration']
            specialites = ['Implantologie', 'Orthodontie', 'Pédiatrie', 'Parodontologie']
            
            for i, utilisateur in enumerate(utilisateurs):
                personnel_data = {
                    'utilisateur': utilisateur.id,
                    'matricule': f'MAT{2024}{i+1:03d}',
                    'date_embauche': f'2020-{(i%12)+1:02d}-15',
                    'service': services[i % len(services)],
                    'specialite': specialites[i % len(specialites)],
                    'telephone_professionnel': f'+2376{12345678+i:08d}',
                    'email_professionnel': f'{utilisateur.username}@warms.com',
                    'statut': 'actif',
                    'competences': ['Soins dentaires', 'Communication', 'Gestion patient'],
                    'certifications': ['Diplôme dentaire', 'Autorisation pratique'],
                }
                
                serializer = PersonnelCreateSerializer(data=personnel_data)
                if serializer.is_valid():
                    personnel = serializer.save()
                    personnel_test.append(PersonnelSerializer(personnel).data)
            
            return Response({
                'message': f'{len(personnel_test)} membres du personnel créés avec succès',
                'personnel': personnel_test
            })
            
        except Exception as e:
            return Response(
                {'error': f'Erreur lors de la création du personnel de test: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class HistoriqueStatutViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet pour l'historique des changements de statut
    """
    
    queryset = HistoriqueStatut.objects.select_related('personnel', 'modifie_par').all()
    serializer_class = HistoriqueStatutSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filtrer par personnel si spécifié
        personnel_id = self.request.query_params.get('personnel_id')
        if personnel_id:
            queryset = queryset.filter(personnel_id=personnel_id)
        
        return queryset.order_by('-date_changement')


class PresenceViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour la gestion des présences
    """
    
    queryset = Presence.objects.select_related('personnel').all()
    serializer_class = PresenceSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filtrer par personnel si spécifié
        personnel_id = self.request.query_params.get('personnel_id')
        if personnel_id:
            queryset = queryset.filter(personnel_id=personnel_id)
        
        # Filtrer par période
        date_debut = self.request.query_params.get('date_debut')
        date_fin = self.request.query_params.get('date_fin')
        
        if date_debut:
            queryset = queryset.filter(date__gte=date_debut)
        if date_fin:
            queryset = queryset.filter(date__lte=date_fin)
        
        return queryset.order_by('-date')
