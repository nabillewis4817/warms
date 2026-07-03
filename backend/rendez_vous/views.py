from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta

from messagerie.models import NotificationInterne

from .models import RendezVous
from .notifications import (
    notifier_rdv_annule,
    notifier_rdv_confirme,
    notifier_rdv_programme,
    notifier_rdv_reporte,
)
from .serializers import RendezVousSerializer


class RendezVousViewSet(viewsets.ModelViewSet):
    queryset = RendezVous.objects.select_related("patient", "praticien", "infirmiere").all()
    serializer_class = RendezVousSerializer

    def perform_create(self, serializer):
        rdv = serializer.save(cree_par=self.request.user)
        notifier_rdv_programme(rdv, acteur=self.request.user)

    def perform_update(self, serializer):
        rdv = serializer.save()
        if rdv.statut == RendezVous.Statut.CONFIRME:
            notifier_rdv_confirme(rdv, acteur=self.request.user)

    @action(detail=True, methods=["post"])
    def annuler(self, request, pk=None):
        rdv = self.get_object()
        raison = request.data.get("raison_annulation", "") or ""
        rdv.statut = RendezVous.Statut.ANNULE
        rdv.raison_annulation = raison
        rdv.save(update_fields=["statut", "raison_annulation", "modifie_le"])
        notifier_rdv_annule(rdv, raison=raison, acteur=request.user)
        return Response(self.get_serializer(rdv).data)

    @action(detail=True, methods=["post"])
    def marquer_absent(self, request, pk=None):
        rdv = self.get_object()
        rdv.statut = RendezVous.Statut.ABSENT
        rdv.motif_absence = request.data.get("motif_absence", "") or ""
        rdv.save(update_fields=["statut", "motif_absence", "modifie_le"])
        return Response(self.get_serializer(rdv).data)

    @action(detail=True, methods=["post"])
    def reporter(self, request, pk=None):
        """
        Déplacer un rendez-vous (avancer / reporter).
        Payload:
        - debut: ISO datetime
        - fin: ISO datetime
        """
        rdv = self.get_object()
        ancienne_date = rdv.debut
        serializer = self.get_serializer(
            rdv,
            data={"debut": request.data.get("debut"), "fin": request.data.get("fin"), "statut": RendezVous.Statut.REPORTE},
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        rdv = serializer.save(statut=RendezVous.Statut.REPORTE)
        notifier_rdv_reporte(rdv, ancienne_date=ancienne_date, acteur=request.user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=False, methods=["post"], url_path="generer-rappels")
    def generer_rappels(self, request):
        debut = timezone.now() + timedelta(hours=20)
        fin = timezone.now() + timedelta(hours=28)
        rdvs = RendezVous.objects.filter(debut__gte=debut, debut__lte=fin)
        created = 0
        for rdv in rdvs:
            if rdv.patient.user_id:
                NotificationInterne.objects.create(
                    destinataire_id=rdv.patient.user_id,
                    titre="Rappel consultation J-1",
                    contenu="Votre consultation est prévue demain.",
                    niveau=NotificationInterne.Niveau.RAPPEL,
                )
                created += 1
            if not rdv.praticien_id:
                # Cas critique: rendez-vous sans chirurgien assigné.
                for user in set(
                    [u.id for u in [rdv.infirmiere, rdv.cree_par] if getattr(u, "id", None)]
                ):
                    NotificationInterne.objects.create(
                        destinataire_id=user,
                        titre="Situation critique",
                        contenu=f"RDV #{rdv.id} sans chirurgien assigné.",
                        niveau=NotificationInterne.Niveau.CRITIQUE,
                    )
        return Response({"created": created})


#EbaJioloLewis
