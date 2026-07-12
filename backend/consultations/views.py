from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q
from django.utils import timezone
from datetime import datetime, timedelta

from personnel.permissions import EstChirurgienDentiste, EstPersonnelCabinet
from personnel.models import Utilisateur
from .models import ActeRealise, Appel, Consultation, PhotoClinique, SchemaDentaire, SuiviDouleur, TauxAbsenteisme
from .serializers import (
    ActeRealiseSerializer,
    AppelSerializer,
    AppelCreateSerializer,
    ConsultationSerializer,
    PhotoCliniqueSerializer,
    SchemaDentaireSerializer,
    SuiviDouleurSerializer,
    TauxAbsenteismeSerializer,
    TauxAbsenteismeCreateSerializer,
)


class ConsultationViewSet(viewsets.ModelViewSet):
    queryset = Consultation.objects.select_related(
        "patient", "dossier", "rendez_vous", "praticien"
    ).all()
    serializer_class = ConsultationSerializer
    permission_classes = [IsAuthenticated]

    ACTIONS_ECRITURE = {"create", "update", "partial_update", "destroy"}

    def get_permissions(self):
        if self.action in self.ACTIONS_ECRITURE:
            return [EstChirurgienDentiste()]
        return [EstPersonnelCabinet()]

    def get_queryset(self):
        qs = super().get_queryset()
        user = self.request.user

        # L'infirmière ne voit que les consultations de ses patients assignés
        if getattr(user, "role", None) == Utilisateur.Role.INFIRMIERE:
            qs = qs.filter(patient__infirmiere_referente=user)

        params = self.request.query_params
        patient_id = params.get("patient")
        praticien_id = params.get("praticien")
        date_debut = params.get("date_debut")
        date_fin = params.get("date_fin")
        search = params.get("search")

        if patient_id:
            qs = qs.filter(patient_id=patient_id)
        if praticien_id:
            qs = qs.filter(praticien_id=praticien_id)
        if date_debut:
            qs = qs.filter(date__date__gte=date_debut)
        if date_fin:
            qs = qs.filter(date__date__lte=date_fin)
        if search:
            qs = qs.filter(
                Q(motif__icontains=search)
                | Q(diagnostic__icontains=search)
                | Q(observations__icontains=search)
                | Q(patient__prenom__icontains=search)
                | Q(patient__nom__icontains=search)
            )
        return qs.order_by("-date")

    def perform_create(self, serializer):
        from rendez_vous.notifications import notifier_consultation_programmee
        patient = serializer.validated_data.get("patient")
        dossier = serializer.validated_data.get("dossier")
        if not dossier and patient is not None:
            dossier = getattr(patient, "dossier", None)
        consultation = serializer.save(dossier=dossier)
        notifier_consultation_programmee(consultation, acteur=self.request.user)

    @action(detail=False, methods=["get"], url_path="export")
    def exporter(self, request):
        """Export CSV des consultations (filtres identiques à la liste)."""
        import csv
        from django.http import HttpResponse

        consultations = self.filter_queryset(self.get_queryset())
        response = HttpResponse(content_type="text/csv; charset=utf-8")
        response["Content-Disposition"] = 'attachment; filename="consultations.csv"'
        writer = csv.writer(response)
        writer.writerow(
            [
                "ID",
                "Patient",
                "Date",
                "Motif",
                "Diagnostic",
                "Praticien",
                "Observations",
            ]
        )
        for c in consultations:
            praticien = ""
            if c.praticien_id:
                praticien = c.praticien.get_full_name() or c.praticien.username
            writer.writerow(
                [
                    c.id,
                    f"{c.patient.prenom} {c.patient.nom}",
                    c.date.strftime("%Y-%m-%d %H:%M") if c.date else "",
                    c.motif,
                    c.diagnostic,
                    praticien,
                    c.observations,
                ]
            )
        return response


class ActeRealiseViewSet(viewsets.ModelViewSet):
    queryset = ActeRealise.objects.select_related("consultation").all()
    serializer_class = ActeRealiseSerializer


class SchemaDentaireViewSet(
    mixins.CreateModelMixin, mixins.ListModelMixin, mixins.UpdateModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet
):
    queryset = SchemaDentaire.objects.select_related("consultation").all()
    serializer_class = SchemaDentaireSerializer


class PhotoCliniqueViewSet(
    mixins.CreateModelMixin, mixins.DestroyModelMixin, mixins.ListModelMixin, viewsets.GenericViewSet
):
    queryset = PhotoClinique.objects.select_related("consultation").all()
    serializer_class = PhotoCliniqueSerializer
    parser_classes = [MultiPartParser, FormParser]

    def create(self, request, *args, **kwargs):
        """
        Upload multipart:
        - consultation: id
        - fichier: image
        - type_photo: pre_op|post_op|autre
        - commentaire: optionnel
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        instance = serializer.save()
        return Response(self.get_serializer(instance).data, status=status.HTTP_201_CREATED)


class AppelViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour la gestion des appels et absences
    """
    queryset = Appel.objects.select_related(
        "patient", "praticien", "rendez_vous", "cree_par"
    ).all()
    serializer_class = AppelSerializer
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        """Utiliser différents serializers selon l'action"""
        if self.action in ['create', 'update', 'partial_update']:
            return AppelCreateSerializer
        return AppelSerializer
    
    def perform_create(self, serializer):
        """Ajouter l'utilisateur qui crée l'appel"""
        serializer.save(cree_par=self.request.user, cree_le=timezone.now())
    
    @action(detail=False, methods=['get'])
    def aujourd_hui(self, request):
        """Récupérer les appels du jour"""
        aujourd_hui = timezone.now().date()
        appels = self.queryset.filter(date_appel=aujourd_hui)
        serializer = self.get_serializer(appels, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def par_date(self, request):
        """Récupérer les appels pour une date spécifique"""
        date_str = request.query_params.get('date')
        if not date_str:
            return Response(
                {"error": "Le paramètre 'date' est requis (format: YYYY-MM-DD)"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            date = datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            return Response(
                {"error": "Format de date invalide. Utilisez YYYY-MM-DD"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        appels = self.queryset.filter(date_appel=date)
        serializer = self.get_serializer(appels, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def statistiques(self, request):
        """Statistiques sur les appels pour la période actuelle"""
        aujourd_hui = timezone.now().date()
        debut_mois = aujourd_hui.replace(day=1)
        
        # Statistiques du mois
        appels_mois = self.queryset.filter(date_appel__gte=debut_mois)
        
        stats = {
            'total_appels': appels_mois.count(),
            'presents': appels_mois.filter(statut='present').count(),
            'absents': appels_mois.filter(statut__in=['absent_justifie', 'absent_non_justifie']).count(),
            'absents_justifies': appels_mois.filter(statut='absent_justifie').count(),
            'absents_non_justifies': appels_mois.filter(statut='absent_non_justifie').count(),
            'en_retard': appels_mois.filter(statut='en_retard').count(),
            'annules': appels_mois.filter(statut='annule').count(),
            'en_attente': appels_mois.filter(statut='en_attente').count(),
        }
        
        # Calculer les taux
        total = stats['total_appels']
        if total > 0:
            stats.update({
                'taux_presence': round((stats['presents'] / total) * 100, 2),
                'taux_absenteisme': round((stats['absents'] / total) * 100, 2),
                'taux_absenteisme_justifie': round((stats['absents_justifies'] / total) * 100, 2),
                'taux_retard': round((stats['en_retard'] / total) * 100, 2),
            })
        else:
            stats.update({
                'taux_presence': 0.0,
                'taux_absenteisme': 0.0,
                'taux_absenteisme_justifie': 0.0,
                'taux_retard': 0.0,
            })
        
        return Response(stats)
    
    @action(detail=False, methods=['post'])
    def appel_rapide(self, request):
        """Faire un appel rapide pour un patient"""
        patient_id = request.data.get('patient_id')
        statut = request.data.get('statut', 'en_attente')
        
        if not patient_id:
            return Response(
                {"error": "L'ID du patient est requis"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Créer l'appel avec les informations minimales
        appel_data = {
            'patient_id': patient_id,
            'date_appel': timezone.now().date(),
            'statut': statut,
        }
        
        serializer = AppelCreateSerializer(data=appel_data)
        if serializer.is_valid():
            appel = serializer.save(cree_par=request.user)
            return Response(AppelSerializer(appel).data, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class TauxAbsenteismeViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour la gestion des taux d'absentéisme
    """
    queryset = TauxAbsenteisme.objects.select_related("praticien").all()
    serializer_class = TauxAbsenteismeSerializer
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        """Utiliser différents serializers selon l'action"""
        if self.action in ['create', 'update', 'partial_update']:
            return TauxAbsenteismeCreateSerializer
        return TauxAbsenteismeSerializer
    
    @action(detail=False, methods=['post'])
    def calculer(self, request):
        """Calculer automatiquement les taux pour une période donnée"""
        periode_debut = request.data.get('periode_debut')
        periode_fin = request.data.get('periode_fin')
        praticien_id = request.data.get('praticien_id')
        type_periode = request.data.get('type_periode', 'mois')
        
        if not periode_debut or not periode_fin:
            return Response(
                {"error": "Les dates de début et fin sont requises"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            debut = datetime.strptime(periode_debut, '%Y-%m-%d').date()
            fin = datetime.strptime(periode_fin, '%Y-%m-%d').date()
        except ValueError:
            return Response(
                {"error": "Format de date invalide. Utilisez YYYY-MM-DD"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Créer ou mettre à jour les taux
        taux_data = {
            'periode_debut': debut,
            'periode_fin': fin,
            'type_periode': type_periode,
        }
        
        if praticien_id:
            taux_data['praticien_id'] = praticien_id
        
        serializer = TauxAbsenteismeCreateSerializer(data=taux_data)
        if serializer.is_valid():
            taux = serializer.save()
            taux.calculer_taux()
            return Response(TauxAbsenteismeSerializer(taux).data)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['get'])
    def actuels(self, request):
        """Récupérer les taux les plus récents"""
        type_periode = request.query_params.get('type_periode', 'mois')
        praticien_id = request.query_params.get('praticien_id')
        
        queryset = self.queryset.filter(type_periode=type_periode)
        if praticien_id:
            queryset = queryset.filter(praticien_id=praticien_id)
        
        # Récupérer le plus récent pour chaque praticien/période
        taux = queryset.order_by('-periode_debut').first()
        if taux:
            return Response(TauxAbsenteismeSerializer(taux).data)
        
        return Response({"message": "Aucun taux trouvé"}, status=status.HTTP_404_NOT_FOUND)
    
    @action(detail=False, methods=['get'])
    def historique(self, request):
        """Récupérer l'historique des taux"""
        type_periode = request.query_params.get('type_periode', 'mois')
        praticien_id = request.query_params.get('praticien_id')
        try:
            limit = min(max(int(request.query_params.get('limit', 12)), 1), 100)
        except (TypeError, ValueError):
            limit = 12

        queryset = self.queryset.filter(type_periode=type_periode)
        if praticien_id:
            queryset = queryset.filter(praticien_id=praticien_id)

        taux = queryset.order_by('-periode_debut')[:limit]
        serializer = self.get_serializer(taux, many=True)
        return Response(serializer.data)


class SuiviDouleurViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = SuiviDouleurSerializer

    def get_queryset(self):
        user = self.request.user
        from patients.models import Patient
        if getattr(user, 'role', None) == 'patient':
            patient = Patient.objects.filter(user=user).first()
            if not patient:
                return SuiviDouleur.objects.none()
            return SuiviDouleur.objects.filter(patient=patient)
        # Personnel: see all or filter by patient query param
        qs = SuiviDouleur.objects.select_related('patient', 'consultation').all()
        patient_id = self.request.query_params.get('patient')
        if patient_id:
            qs = qs.filter(patient_id=patient_id)
        return qs

    def perform_create(self, serializer):
        from patients.models import Patient
        user = self.request.user
        if getattr(user, 'role', None) == 'patient':
            patient = Patient.objects.filter(user=user).first()
            if patient:
                serializer.save(patient=patient)
                return
        serializer.save()


#EbaJioloLewis
