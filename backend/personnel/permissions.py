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
        # Les superutilisateurs ont tous les droits
        if user.is_superuser:
            return True
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
        # Les superutilisateurs ont tous les droits
        if user.is_superuser:
            return True
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
            and (user.is_superuser or getattr(user, "role", None) == Utilisateur.Role.CHIRURGIEN_DENTISTE)
        )


class EstPatient(BasePermission):
    """
    Autorise uniquement les patients (et superutilisateurs pour le debug).
    """

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        # Les superutilisateurs ont tous les droits
        if user.is_superuser:
            return True
        return getattr(user, "role", None) == Utilisateur.Role.PATIENT


class EstUtilisateurAuthentifie(BasePermission):
    """
    Autorise tous les utilisateurs authentifiés (personnel et patients).
    """

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated)


class PeutVoirJournaux(BasePermission):
    """Journaux d'audit réservés au chirurgien-dentiste et aux superutilisateurs."""
    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if user.is_superuser:
            return True
        return getattr(user, "role", None) == Utilisateur.Role.CHIRURGIEN_DENTISTE


#EbaJioloLewis
