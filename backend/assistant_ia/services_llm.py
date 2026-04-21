from __future__ import annotations

import json
import urllib.error
import urllib.request

from django.conf import settings


def reponse_ia(question: str, contexte: str) -> str:
    """
    Réponse IA provider-aware.

    Priorité actuelle:
    1) Anthropic Claude (si clé dispo)
    2) fallback local heuristique
    """
    api_key = getattr(settings, "ANTHROPIC_API_KEY", "")
    model = getattr(settings, "ANTHROPIC_MODEL", "claude-3-5-sonnet-latest")

    if api_key:
        prompt = (
            "Tu es un assistant clinique pour un cabinet dentaire.\n"
            "Réponds en français, de manière claire, prudente et concise.\n"
            "N'invente pas des données absentes du contexte.\n\n"
            f"Contexte dossier:\n{contexte}\n\n"
            f"Question:\n{question}\n"
        )
        payload = {
            "model": model,
            "max_tokens": 500,
            "messages": [{"role": "user", "content": prompt}],
        }
        req = urllib.request.Request(
            "https://api.anthropic.com/v1/messages",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                body = json.loads(response.read().decode("utf-8"))
                content = body.get("content", [])
                if content and isinstance(content, list):
                    text = content[0].get("text", "").strip()
                    if text:
                        return text
        except (urllib.error.URLError, TimeoutError, ValueError, KeyError):
            pass

    return (
        "Réponse IA locale (fallback): "
        "j'ai analysé le contexte disponible, mais aucune connexion fournisseur IA n'est active."
    )


#EbaJioloLewis
