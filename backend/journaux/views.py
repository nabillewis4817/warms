from rest_framework import viewsets

from .models import LogActivite
from .serializers import LogActiviteSerializer


class LogActiviteViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Lecture seule: le backend écrit les logs, l'admin les consulte.
    """

    queryset = LogActivite.objects.select_related("acteur").all()
    serializer_class = LogActiviteSerializer


#EbaJioloLewis
