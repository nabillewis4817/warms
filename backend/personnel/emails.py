"""Envoi des emails de confirmation (création de compte, mot de passe).

Utilise les templates HTML/texte de `templates/emails/`. Aucune exception
n'est jamais levée vers l'appelant : un échec d'envoi (SMTP indisponible,
etc.) ne doit jamais faire échouer la création de compte ou la
réinitialisation de mot de passe qui l'a déclenché.
"""

import logging

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils import timezone

logger = logging.getLogger(__name__)


def _envoyer(destinataire, sujet, template_base, contexte):
    if not destinataire:
        return False
    contexte = {
        "site_name": settings.SITE_NAME,
        "frontend_url": settings.FRONTEND_URL,
        "annee": timezone.now().year,
        **contexte,
    }
    try:
        texte = render_to_string(f"emails/{template_base}.txt", contexte)
        html = render_to_string(f"emails/{template_base}.html", contexte)
        message = EmailMultiAlternatives(
            subject=sujet,
            body=texte,
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[destinataire],
        )
        message.attach_alternative(html, "text/html")
        message.send(fail_silently=False)
        return True
    except Exception:
        logger.exception("Échec de l'envoi de l'email '%s' à %s", template_base, destinataire)
        return False


def envoyer_email_compte_cree(utilisateur, mot_de_passe=None, en_attente_validation=False):
    """Confirme la création (et, le cas échéant, l'approbation) d'un compte
    personnel ou patient."""
    return _envoyer(
        destinataire=utilisateur.email,
        sujet=f"Votre compte {settings.SITE_NAME} a été créé",
        template_base="compte_cree",
        contexte={
            "prenom": utilisateur.first_name or utilisateur.username,
            "username": utilisateur.username,
            "role_label": utilisateur.get_role_display(),
            "mot_de_passe": mot_de_passe,
            "en_attente_validation": en_attente_validation,
        },
    )


def envoyer_email_mot_de_passe_modifie(utilisateur):
    """Confirme qu'une réinitialisation de mot de passe a réussi."""
    return _envoyer(
        destinataire=utilisateur.email,
        sujet=f"Votre mot de passe {settings.SITE_NAME} a été modifié",
        template_base="mot_de_passe_modifie",
        contexte={
            "prenom": utilisateur.first_name or utilisateur.username,
        },
    )
