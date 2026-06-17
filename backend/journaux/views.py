from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.http import HttpResponse
from django.db.models import Q
import csv
from datetime import datetime

from .models import LogActivite
from .serializers import LogActiviteSerializer, LogActiviteCreateSerializer


class LogActiviteViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Vue pour les journaux d'activité - Lecture seule pour les utilisateurs
    """

    queryset = LogActivite.objects.select_related("acteur").all()
    serializer_class = LogActiviteSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = super().get_queryset()
        
        # Filtrage par recherche
        recherche = self.request.query_params.get('recherche', '')
        if recherche:
            queryset = queryset.filter(
                Q(action__icontains=recherche) |
                Q(details__icontains=recherche) |
                Q(acteur__username__icontains=recherche) |
                Q(acteur__first_name__icontains=recherche) |
                Q(acteur__last_name__icontains=recherche)
            )
        
        # Filtrage par date
        date_debut = self.request.query_params.get('dateDebut')
        date_fin = self.request.query_params.get('dateFin')
        if date_debut:
            queryset = queryset.filter(cree_le__date__gte=date_debut)
        if date_fin:
            queryset = queryset.filter(cree_le__date__lte=date_fin)
        
        # Filtrage par type
        type_log = self.request.query_params.get('type')
        if type_log:
            queryset = queryset.filter(type_action=type_log)

        # Filtrage par utilisateur
        utilisateur = self.request.query_params.get('utilisateur')
        if utilisateur:
            queryset = queryset.filter(
                Q(acteur__username__icontains=utilisateur) |
                Q(acteur__first_name__icontains=utilisateur) |
                Q(acteur__last_name__icontains=utilisateur)
            )

        return queryset.order_by('-cree_le')

    @action(detail=False, methods=['get'])
    def exporter(self, request):
        """
        Exporter les journaux au format CSV
        """
        queryset = self.get_queryset()
        
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = f'attachment; filename="journaux_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['Date', 'Utilisateur', 'Action', 'Détails', 'Type', 'IP'])
        
        for log in queryset:
            writer.writerow([
                log.cree_le.strftime('%Y-%m-%d %H:%M:%S') if log.cree_le else '',
                f"{log.acteur.first_name} {log.acteur.last_name}" if log.acteur else '',
                log.action,
                log.details,
                log.type_action,
                log.adresse_ip or ''
            ])
        
        return response

    @action(detail=False, methods=['get'])
    def types(self, request):
        """
        Obtenir la liste des types de journaux disponibles
        """
        types = LogActivite.objects.values_list('type_action', flat=True).distinct()
        return Response(list(types))

    @action(detail=False, methods=['get'])
    def utilisateurs(self, request):
        """
        Obtenir la liste des utilisateurs ayant des journaux
        """
        utilisateurs = set()
        for log in LogActivite.objects.select_related('acteur'):
            if log.acteur:
                utilisateurs.add(f"{log.acteur.first_name} {log.acteur.last_name}")
        return Response(list(utilisateurs))

    @action(detail=False, methods=['get'])
    def statistiques(self, request):
        """
        Obtenir les statistiques des journaux
        """
        total_logs = LogActivite.objects.count()
        stats_par_type = {}
        
        for log_type in LogActivite.objects.values_list('type_action', flat=True).distinct():
            stats_par_type[log_type] = LogActivite.objects.filter(type_action=log_type).count()
        
        return Response({
            'total': total_logs,
            'par_type': stats_par_type
        })

    @action(detail=False, methods=['post'])
    def creer_donnees_test(self, request):
        """Crée des données de test pour les journaux (développement uniquement)"""
        from django.contrib.auth import get_user_model
        User = get_user_model()
        
        try:
            # Récupérer quelques utilisateurs pour les logs
            utilisateurs = User.objects.all()[:5]
            
            if not utilisateurs:
                return Response(
                    {'error': 'Aucun utilisateur trouvé pour créer les logs de test'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            logs_test = [
                {
                    'action': 'Création patient',
                    'type_action': 'patient',
                    'details': 'Patient DOE John créé avec dossier WARMS-000001',
                    'objet_type': 'Patient',
                    'objet_id': '1',
                    'metadata': {'patient_id': 1, 'dossier': 'WARMS-000001'}
                },
                {
                    'action': 'Modification consultation',
                    'type_action': 'consultation',
                    'details': 'Consultation du patient Smith modifiée',
                    'objet_type': 'Consultation',
                    'objet_id': '1',
                    'metadata': {'consultation_id': 1, 'patient_id': 2}
                },
                {
                    'action': 'Création rendez-vous',
                    'type_action': 'rendez_vous',
                    'details': 'Rendez-vous créé pour patient Dupont',
                    'objet_type': 'RendezVous',
                    'objet_id': '1',
                    'metadata': {'rendez_vous_id': 1, 'patient_id': 3}
                },
                {
                    'action': 'Connexion au système',
                    'type_action': 'connexion',
                    'details': 'Connexion réussie',
                    'objet_type': 'User',
                    'metadata': {'login_method': 'password'}
                },
                {
                    'action': 'Suppression dossier',
                    'type_action': 'suppression',
                    'details': 'Dossier patient archivé',
                    'objet_type': 'Patient',
                    'objet_id': '4',
                    'metadata': {'patient_id': 4, 'archive': True}
                },
            ]
            
            logs_crees = []
            for i, log_data in enumerate(logs_test):
                serializer = LogActiviteCreateSerializer(
                    data=log_data,
                    context={'request': request}
                )
                if serializer.is_valid():
                    log = serializer.save(acteur=utilisateurs[i % len(utilisateurs)])
                    logs_crees.append(LogActiviteSerializer(log).data)
            
            return Response({
                'message': f'{len(logs_crees)} logs de test créés avec succès',
                'logs': logs_crees
            })
            
        except Exception as e:
            return Response(
                {'error': f'Erreur lors de la création des logs de test: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


def journaliser_action(utilisateur, action, type_action, details="", objet_type="", objet_id="", metadata=None):
    """
    Fonction utilitaire pour créer un log d'activité
    """
    if metadata is None:
        metadata = {}
    
    try:
        LogActivite.objects.create(
            acteur=utilisateur,
            action=action,
            type_action=type_action,
            details=details,
            objet_type=objet_type,
            objet_id=str(objet_id),
            metadata=metadata
        )
    except Exception as e:
        print(f"Erreur lors de la journalisation: {e}")


#EbaJioloLewis
