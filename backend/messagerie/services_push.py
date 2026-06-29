"""Envoi de notifications push mobiles via Firebase Cloud Messaging (FCM).

Désactivé silencieusement si `FIREBASE_CREDENTIALS_PATH` n'est pas configuré
(cas du dev local tant que le projet Firebase n'existe pas encore) : aucune
erreur ne doit jamais remonter jusqu'à la création d'une NotificationInterne,
qui doit réussir même si l'envoi push échoue.
"""

import logging

from django.conf import settings

logger = logging.getLogger(__name__)

_app = None
_tentative_initialisation_faite = False


def _obtenir_app_firebase():
    """Initialise paresseusement le SDK Firebase Admin (une seule fois)."""
    global _app, _tentative_initialisation_faite
    if _app is not None:
        return _app
    if _tentative_initialisation_faite:
        return None
    _tentative_initialisation_faite = True

    chemin = getattr(settings, "FIREBASE_CREDENTIALS_PATH", "")
    if not chemin:
        logger.info(
            "FIREBASE_CREDENTIALS_PATH non configuré : notifications push désactivées."
        )
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(chemin)
        _app = firebase_admin.initialize_app(cred)
        return _app
    except Exception as exc:
        logger.warning("Initialisation Firebase Admin impossible: %s", exc)
        return None


def envoyer_notification_push(utilisateur, titre, corps, donnees=None):
    """Envoie une notification push au jeton FCM de `utilisateur`, si connu.

    Ne lève jamais d'exception : un échec d'envoi push ne doit pas faire
    échouer l'action métier qui l'a déclenché (ex: créer un message).
    """
    token = getattr(utilisateur, "fcm_token", "") or ""
    if not token:
        return False

    app = _obtenir_app_firebase()
    if app is None:
        return False

    try:
        from firebase_admin import messaging

        message = messaging.Message(
            notification=messaging.Notification(title=titre, body=corps),
            data={str(k): str(v) for k, v in (donnees or {}).items()},
            token=token,
        )
        messaging.send(message, app=app)
        return True
    except Exception as exc:
        logger.warning("Échec envoi notification push à l'utilisateur %s: %s", utilisateur.pk, exc)
        return False
