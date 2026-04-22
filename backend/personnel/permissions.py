from rest_framework.permissions import BasePermission

from .models import Utilisateur


class EstPersonnelCabinet(BasePermission):
    """
    Autorise uniquement le personnel du cabinet (pas les patients).
    """

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        return getattr(user, "role", None) in {
            Utilisateur.Role.CHIRURGIEN_DENTISTE,
            Utilisateur.Role.SECRETAIRE,
            Utilisateur.Role.INFIRMIERE,
        }


class PeutGererComptes(BasePermission):
    """
    Gestion des comptes (création/modification): chirurgien-dentiste ou secrétaire.
    """

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        return getattr(user, "role", None) in {
            Utilisateur.Role.CHIRURGIEN_DENTISTE,
            Utilisateur.Role.SECRETAIRE,
        }


class EstChirurgienDentiste(BasePermission):
    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and getattr(user, "role", None) == Utilisateur.Role.CHIRURGIEN_DENTISTE
        )


#EbaJioloLewis
