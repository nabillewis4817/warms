from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta

from messagerie.models import NotificationInterne

from .models import RendezVous
from .serializers import RendezVousSerializer


class RendezVousViewSet(viewsets.ModelViewSet):
    queryset = RendezVous.objects.select_related("patient", "praticien", "infirmiere").all()
    serializer_class = RendezVousSerializer

    def perform_create(self, serializer):
        serializer.save(cree_par=self.request.user)

    @action(detail=True, methods=["post"])
    def annuler(self, request, pk=None):
        rdv = self.get_object()
        rdv.statut = RendezVous.Statut.ANNULE
        rdv.raison_annulation = request.data.get("raison_annulation", "") or ""
        rdv.save(update_fields=["statut", "raison_annulation", "modifie_le"])
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
        serializer = self.get_serializer(
            rdv,
            data={"debut": request.data.get("debut"), "fin": request.data.get("fin"), "statut": RendezVous.Statut.REPORTE},
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save(statut=RendezVous.Statut.REPORTE)
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
