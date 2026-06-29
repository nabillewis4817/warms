from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import NotificationInterne
from .services_push import envoyer_notification_push


@receiver(post_save, sender=NotificationInterne)
def envoyer_push_sur_notification_interne(sender, instance, created, **kwargs):
    """Relaie chaque NotificationInterne créée vers une notification push
    mobile (no-op silencieux si Firebase n'est pas configuré ou si
    l'utilisateur n'a pas d'appareil enregistré)."""
    if not created:
        return
    envoyer_notification_push(
        utilisateur=instance.destinataire,
        titre=instance.titre,
        corps=instance.contenu or instance.titre,
        donnees={"niveau": instance.niveau, "notification_id": instance.id},
    )
