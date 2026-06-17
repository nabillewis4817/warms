from datetime import timedelta

from django.utils import timezone

SEUIL_MISE_A_JOUR = timedelta(seconds=30)


class ActivitePresenceMiddleware:
    """
    Met à jour discrètement `derniere_activite` sur l'utilisateur authentifié
    à chaque requête, pour alimenter l'indicateur de présence en ligne
    (messagerie, etc.) sans nécessiter de WebSocket ni d'appel dédié.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        user = getattr(request, "user", None)
        if user is not None and getattr(user, "is_authenticated", False):
            maintenant = timezone.now()
            derniere = getattr(user, "derniere_activite", None)
            if not derniere or maintenant - derniere > SEUIL_MISE_A_JOUR:
                type(user).objects.filter(pk=user.pk).update(derniere_activite=maintenant)

        return response
