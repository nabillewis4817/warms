from typing import Any

from .models import LogActivite


def journaliser(
    *,
    acteur,
    action: str,
    objet_type: str = "",
    objet_id: str = "",
    message: str = "",
    metadata: dict[str, Any] | None = None,
):
    """
    Helper: centralise l'écriture des logs.
    """
    LogActivite.objects.create(
        acteur=acteur if getattr(acteur, "is_authenticated", False) else None,
        action=action,
        objet_type=objet_type,
        objet_id=str(objet_id) if objet_id is not None else "",
        message=message,
        metadata=metadata or {},
    )


#EbaJioloLewis
