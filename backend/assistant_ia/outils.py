"""
Outils CRUD de l'assistant WARMS IA.

Deux façons d'identifier une action à partir d'un message libre :
1. `appeler_claude_avec_outils` : Claude avec function calling (si une clé
   ANTHROPIC_API_KEY est configurée) — comprend des formulations libres.
2. `detecter_intention_locale` : analyseur par mots-clés/regex, sans aucune
   dépendance externe — permet à l'assistant de fonctionner "manuellement"
   même sans clé API configurée.

Les deux convergent vers le même format `{"name": ..., "input": {...}}`,
exécuté ensuite par `executer_action`.
"""
from __future__ import annotations

import json
import re
import urllib.error
import urllib.request

from django.conf import settings
from django.db.models import Q

from patients.models import Patient

PAGES_CONNUES = {
    "tableau de bord": "/tableau-de-bord",
    "dashboard": "/tableau-de-bord",
    "accueil": "/tableau-de-bord",
    "patients": "/patients",
    "liste des patients": "/patients",
    "nouveau patient": "/patients/nouveau",
    "carnets": "/carnets",
    "ocr": "/ocr",
    "assistant": "/ia-warms",
    "ia": "/ia-warms",
    "messagerie": "/messagerie",
    "messages": "/messagerie",
    "prescriptions": "/prescriptions",
    "ordonnances": "/prescriptions",
    "personnel": "/personnel",
    "équipe": "/personnel",
    "equipe": "/personnel",
    "paramètres": "/parametres/profil",
    "parametres": "/parametres/profil",
    "profil": "/parametres/profil",
    "consultations": "/consultations",
    "rendez-vous": "/rendez-vous",
    "rendez vous": "/rendez-vous",
    "rdv": "/rendez-vous",
    "appels": "/appels",
    "taux d'absentéisme": "/taux-absenteisme",
    "absenteisme": "/taux-absenteisme",
    "statistiques": "/statistiques",
    "journaux": "/journaux",
    "avis": "/avis",
}

OUTILS_CLAUDE = [
    {
        "name": "ouvrir_dossier_patient",
        "description": "Ouvre le dossier d'un patient existant à partir de son nom et/ou prénom.",
        "input_schema": {
            "type": "object",
            "properties": {"nom_complet": {"type": "string", "description": "Nom et/ou prénom du patient à rechercher"}},
            "required": ["nom_complet"],
        },
    },
    {
        "name": "creer_patient",
        "description": "Crée une nouvelle fiche patient avec les informations fournies.",
        "input_schema": {
            "type": "object",
            "properties": {
                "prenom": {"type": "string"},
                "nom": {"type": "string"},
                "telephone": {"type": "string"},
                "email": {"type": "string"},
                "date_naissance": {"type": "string", "description": "Format JJ/MM/AAAA ou AAAA-MM-JJ"},
                "sexe": {"type": "string", "enum": ["M", "F"]},
                "allergies": {"type": "string"},
            },
            "required": ["prenom", "nom"],
        },
    },
    {
        "name": "changer_theme",
        "description": "Change le thème visuel de l'application.",
        "input_schema": {
            "type": "object",
            "properties": {"mode": {"type": "string", "enum": ["clair", "sombre"]}},
            "required": ["mode"],
        },
    },
    {
        "name": "verifier_allergies",
        "description": "Recherche et indique les allergies déclarées d'un patient.",
        "input_schema": {
            "type": "object",
            "properties": {"nom_complet": {"type": "string"}},
            "required": ["nom_complet"],
        },
    },
    {
        "name": "naviguer",
        "description": (
            "Navigue vers une page de l'application : tableau de bord, patients, carnets, ocr, "
            "messagerie, prescriptions, personnel, paramètres, consultations, rendez-vous, appels, "
            "statistiques, journaux, avis, assistant."
        ),
        "input_schema": {
            "type": "object",
            "properties": {"page": {"type": "string"}},
            "required": ["page"],
        },
    },
]

# Actions qui modifient l'état de l'app ou naviguent : confirmées avant
# exécution. "verifier_allergies" est une simple lecture, répondue directement.
ACTIONS_NECESSITANT_CONFIRMATION = {"ouvrir_dossier_patient", "creer_patient", "changer_theme", "naviguer"}


def rechercher_patient(nom_complet: str) -> Patient | None:
    termes = [t for t in re.split(r"\s+", (nom_complet or "").strip()) if t]
    if not termes:
        return None

    requete = Q()
    for terme in termes:
        requete |= Q(nom__icontains=terme) | Q(prenom__icontains=terme)
    candidats = list(Patient.objects.filter(requete)[:10])

    if not candidats:
        return None
    if len(candidats) == 1:
        return candidats[0]

    cible = nom_complet.strip().lower()
    for c in candidats:
        nom_candidat = f"{c.prenom} {c.nom}".lower()
        if cible in nom_candidat or nom_candidat in cible:
            return c
    return candidats[0]


def resoudre_page(libelle: str) -> str | None:
    cle = (libelle or "").strip().lower()
    if cle in PAGES_CONNUES:
        return PAGES_CONNUES[cle]
    for nom, chemin in PAGES_CONNUES.items():
        if nom in cle or cle in nom:
            return chemin
    return None


def detecter_intention_locale(message: str) -> dict | None:
    """Analyseur par mots-clés (mode manuel, sans LLM)."""
    m = (message or "").strip().lower()
    if not m:
        return None

    # Plus spécifique en premier : "ouvrir le dossier de X" ne doit pas être
    # capté par le pattern générique "naviguer" plus bas.
    match = re.search(
        r"(?:ouvre|ouvrir|affiche|afficher|voir|montre|montrer)\s+(?:le\s+)?dossier\s+(?:du|de|d['’])?\s*(?:patient\s+)?([a-zà-ÿ\s\-]+)",
        m,
    )
    if match:
        return {"name": "ouvrir_dossier_patient", "input": {"nom_complet": match.group(1).strip()}}

    match = re.search(
        r"(?:cr[ée]e?r?|ajoute|ajouter)\s+(?:le\s+)?(?:dossier\s+(?:du\s+)?patient|patient|fiche\s+patient)\s+([a-zà-ÿ\s\-]+)",
        m,
    )
    if match:
        parties = match.group(1).strip().split()
        prenom = parties[0].capitalize() if parties else ""
        nom = " ".join(parties[1:]).upper() if len(parties) > 1 else ""
        return {"name": "creer_patient", "input": {"prenom": prenom, "nom": nom}}

    match = re.search(
        r"(?:change|changer|passe|passer|mettre|mets)\s+(?:le\s+)?th[èe]me\s+(?:en|au)?\s*(clair|sombre|jour|nuit)",
        m,
    )
    if match:
        valeur = match.group(1)
        mode = "sombre" if valeur in ("sombre", "nuit") else "clair"
        return {"name": "changer_theme", "input": {"mode": mode}}

    match = re.search(r"allergies?\s+(?:du|de|d['’])?\s*(?:patient\s+)?([a-zà-ÿ\s\-]+)", m)
    if match:
        return {"name": "verifier_allergies", "input": {"nom_complet": match.group(1).strip()}}

    match = re.search(
        r"(?:ouvre|ouvrir|va\s+(?:à|sur)|aller\s+(?:à|sur)|affiche|afficher|montre|montrer)\s+"
        r"(?:la\s+|le\s+|les\s+|l['’])?(?:page\s+|section\s+|onglet\s+)?([a-zà-ÿ\-\s']+)",
        m,
    )
    if match:
        libelle = match.group(1).strip()
        if resoudre_page(libelle):
            return {"name": "naviguer", "input": {"page": libelle}}

    return None


def appeler_claude_avec_outils(message: str) -> dict | None:
    """Demande à Claude d'identifier l'outil à appeler (function calling)."""
    api_key = getattr(settings, "ANTHROPIC_API_KEY", "")
    if not api_key or not api_key.strip():
        return None

    model = getattr(settings, "ANTHROPIC_MODEL", "claude-3-5-sonnet-latest")
    payload = {
        "model": model,
        "max_tokens": 500,
        "tools": OUTILS_CLAUDE,
        "messages": [{"role": "user", "content": message}],
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
            for bloc in body.get("content", []):
                if bloc.get("type") == "tool_use":
                    return {"name": bloc["name"], "input": bloc.get("input", {})}
    except (urllib.error.URLError, TimeoutError, ValueError, KeyError) as e:
        print(f"Erreur appel Claude (outils): {e}")
    return None


def description_lisible(nom_action: str, parametres: dict) -> str:
    if nom_action == "ouvrir_dossier_patient":
        return f"Ouvrir le dossier du patient « {parametres.get('nom_complet', '')} » ?"
    if nom_action == "creer_patient":
        return f"Créer une nouvelle fiche patient pour {parametres.get('prenom', '')} {parametres.get('nom', '')} ?"
    if nom_action == "changer_theme":
        return f"Basculer le thème de l'application en mode {parametres.get('mode', '')} ?"
    if nom_action == "naviguer":
        return f"Ouvrir la page « {parametres.get('page', '')} » ?"
    return "Confirmer cette action ?"


def executer_action(nom_action: str, parametres: dict, utilisateur) -> dict:
    """Exécute réellement une action confirmée. Retourne un résultat normalisé pour le frontend."""
    parametres = parametres or {}

    if nom_action == "ouvrir_dossier_patient":
        patient = rechercher_patient(parametres.get("nom_complet", ""))
        if not patient:
            return {"succes": False, "message": f"Aucun patient trouvé pour « {parametres.get('nom_complet', '')} »."}
        return {
            "succes": True,
            "effet": {"type": "naviguer", "chemin": f"/patients/{patient.id}/dossier"},
            "message": f"J'ouvre le dossier de {patient.prenom} {patient.nom}.",
        }

    if nom_action == "verifier_allergies":
        patient = rechercher_patient(parametres.get("nom_complet", ""))
        if not patient:
            return {"succes": False, "message": f"Aucun patient trouvé pour « {parametres.get('nom_complet', '')} »."}
        dossier = getattr(patient, "dossier", None)
        allergies = dossier.allergies if dossier and dossier.allergies else ""
        if allergies:
            return {"succes": True, "message": f"{patient.prenom} {patient.nom} a déclaré être allergique à : {allergies}."}
        return {"succes": True, "message": f"Aucune allergie connue n'est déclarée pour {patient.prenom} {patient.nom}."}

    if nom_action == "changer_theme":
        mode = parametres.get("mode", "clair")
        return {
            "succes": True,
            "effet": {"type": "changer_theme", "mode": mode},
            "message": f"Thème basculé en mode {mode}.",
        }

    if nom_action == "naviguer":
        chemin = resoudre_page(parametres.get("page", ""))
        if not chemin:
            return {"succes": False, "message": f"Je ne connais pas la page « {parametres.get('page', '')} »."}
        return {
            "succes": True,
            "effet": {"type": "naviguer", "chemin": chemin},
            "message": "J'ouvre la page demandée.",
        }

    if nom_action == "creer_patient":
        from rest_framework.test import APIRequestFactory, force_authenticate

        from patients.views import PatientViewSet

        payload = {cle: valeur for cle, valeur in parametres.items() if valeur}
        if not payload.get("prenom") or not payload.get("nom"):
            return {"succes": False, "message": "Le prénom et le nom du patient sont obligatoires."}

        factory = APIRequestFactory()
        req = factory.post("/api/v1/patients/", payload, format="json")
        force_authenticate(req, user=utilisateur)
        reponse = PatientViewSet.as_view({"post": "create"})(req)

        if reponse.status_code == 201:
            return {
                "succes": True,
                "effet": {"type": "naviguer", "chemin": f"/patients/{reponse.data['id']}/dossier"},
                "message": f"Patient {payload.get('prenom')} {payload.get('nom')} créé avec succès.",
            }
        if "photo" in str(reponse.data).lower():
            # Une photo est obligatoire à la création (sert d'identification
            # à la connexion mobile) : l'assistant ne peut pas la fournir
            # depuis une commande texte/vocale — on oriente vers le
            # formulaire complet plutôt que d'échouer sans solution.
            return {
                "succes": False,
                "effet": {"type": "naviguer", "chemin": "/patients/nouveau"},
                "message": (
                    f"Une photo est obligatoire pour créer un patient, je ne peux pas la fournir moi-même. "
                    f"Je vous ouvre le formulaire pour terminer la fiche de {payload.get('prenom')} {payload.get('nom')}."
                ),
            }
        return {"succes": False, "message": f"Échec de la création du patient : {reponse.data}"}

    return {"succes": False, "message": "Action non reconnue."}


#EbaJioloLewis
