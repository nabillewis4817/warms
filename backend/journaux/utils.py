from typing import Any

from .models import LogActivite


def _infer_type_action(action: str) -> str:
    action_lower = (action or "").lower()
    if "patient" in action_lower:
        return "patient"
    if "consultation" in action_lower:
        return "consultation"
    if "rendez" in action_lower or "appointment" in action_lower:
        return "rendez_vous"
    if "ordonnance" in action_lower or "prescription" in action_lower:
        return "ordonnance"
    if "personnel" in action_lower or "user." in action_lower:
        return "personnel"
    if "login" in action_lower or "connexion" in action_lower or "auth" in action_lower:
        return "connexion"
    if "delet" in action_lower or "suppression" in action_lower or "archiv" in action_lower:
        return "suppression"
    if "updat" in action_lower or "modif" in action_lower or "chang" in action_lower:
        return "modification"
    return "systeme"


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
    try:
        LogActivite.objects.create(
            acteur=acteur if getattr(acteur, "is_authenticated", False) else None,
            action=action,
            type_action=_infer_type_action(action),
            details=message,
            objet_type=objet_type,
            objet_id=str(objet_id) if objet_id is not None else "",
            metadata=metadata or {},
        )
    except Exception as exc:
        print(f"Erreur journalisation ({action}): {exc}")


#EbaJioloLewis
