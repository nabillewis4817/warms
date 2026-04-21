from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

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


#EbaJioloLewis
