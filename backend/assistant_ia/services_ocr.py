import re
from typing import Tuple

import pytesseract
from PIL import Image, ImageEnhance, ImageFilter
from django.conf import settings
from django.core.files.uploadedfile import InMemoryUploadedFile

_tesseract_path = getattr(settings, "TESSERACT_PATH", None)
if _tesseract_path:
    pytesseract.pytesseract.tesseract_cmd = _tesseract_path


class TesseractIndisponible(Exception):
    """Levée quand le binaire Tesseract OCR n'est pas accessible sur le système."""


def extraire_texte_image(image_file: InMemoryUploadedFile, lang: str = "fra") -> Tuple[str, float]:
    """
    Extrait le texte d'une image avec Tesseract OCR.
    Lance deux passes (PSM 3 + PSM 6) et fusionne leurs résultats : chaque mode
    capture différemment les tableaux à colonnes et les textes en bloc,
    la fusion maximise la couverture des champs.
    Retourne (texte_fusionné, confiance 0-1).
    """
    try:
        pytesseract.get_tesseract_version()
    except Exception as e:
        raise TesseractIndisponible(
            "Le moteur Tesseract OCR n'est pas installé ou accessible sur le serveur."
        ) from e

    image = Image.open(image_file)
    image = _pretraiter_image(image)

    textes = []
    confiances_totales: list[float] = []

    for psm in (3, 6):
        config = f"--psm {psm} --oem 3 -c preserve_interword_spaces=1"
        t = pytesseract.image_to_string(image, lang=lang, config=config).strip()
        if t:
            textes.append(t)
        d = pytesseract.image_to_data(image, lang=lang, config=config,
                                       output_type=pytesseract.Output.DICT)
        confiances_totales += [
            float(c) for c in d.get("conf", [])
            if c not in ("-1", -1) and float(c) >= 0
        ]

    # Fusion : on concatène les deux textes pour que les regex profitent
    # des deux lectures. Un séparateur clair évite les collisions de tokens.
    texte = "\n\n---\n\n".join(textes)
    confiance = (sum(confiances_totales) / len(confiances_totales) / 100) if confiances_totales else 0.0

    return texte, confiance


def _pretraiter_image(image: Image.Image) -> Image.Image:
    """
    Pré-traitement adapté aux formulaires médicaux :
    - agrandissement si trop petite (Tesseract préfère 300 dpi min)
    - conversion en niveaux de gris
    - légère amélioration contraste + netteté
    On évite volontairement la binarisation fixe (seuil 128) qui détruit
    les tableaux à fond légèrement grisé et fait chuter la précision sur les
    cellules adjacentes.
    """
    w, h = image.size
    # Résolution cible : au moins 2000px de large pour un scan A4
    if w < 2000:
        facteur = 2000 / w
        image = image.resize(
            (int(w * facteur), int(h * facteur)), Image.LANCZOS
        )

    if image.mode != 'L':
        image = image.convert('L')

    # Contraste modéré (1.5) pour les tableaux sans écraser les tons clairs
    image = ImageEnhance.Contrast(image).enhance(1.5)
    # Légère netteté pour améliorer la détection des bords de caractères
    image = ImageEnhance.Sharpness(image).enhance(1.8)

    return image


# ---------------------------------------------------------------------------
# Parsing structuré
# ---------------------------------------------------------------------------

# Borne de fin générique : toute séquence MAJ(2+) optionnellement suivie
# d'un suffixe entre parenthèses (ex: "(S)") puis d'un signe ":"/"-".
# Cela gère PRÉNOM(S) :, DATE DE NAISSANCE :, etc. sans énumérer chaque label.
_STOP = r'(?=\s{1,3}[A-ZÀ-Ÿ]{2}[A-ZÀ-Ÿ\s]{0,30}(?:\([A-Z]+\))?\s*[:\-]|\n\n|$)'


def _extraire(texte: str, pattern_label: str) -> str | None:
    """
    Extrait la valeur associée à un label dans le texte OCR.
    Stratégie : LABEL [:-] <valeur jusqu'au prochain label ou fin de ligne>
    """
    rx = re.compile(
        rf'(?:^|\n|\s)(?:{pattern_label})\s*[:\-]\s*'
        rf'([^\n:{{}}]{{1,120}}?)'
        rf'{_STOP}',
        re.IGNORECASE | re.MULTILINE,
    )
    m = rx.search(texte)
    if not m:
        return None
    val = m.group(1).strip()
    # Rejeter les valeurs parasites (trop courtes ou contenant un autre label)
    if len(val) < 1:
        return None
    # Nettoyer les espaces multiples résidus de colonnes de tableau
    val = re.sub(r'\s{3,}', ' ', val).strip()
    return val if val else None


def analyser_carnet_medical(texte: str) -> dict:
    """
    Parse le texte OCR d'un carnet/formulaire médical.
    Gère les formulaires à colonnes (label et valeur sur la même ligne),
    les labels all-caps (NOM : vs Nom :) et les variantes d'orthographe
    (PRÉNOM / PRENOM / PRÉNOM(S)).
    """
    if not texte:
        return {"erreur": "Aucun texte à analyser"}

    donnees: dict[str, str] = {}

    # ── NOM ────────────────────────────────────────────────────────────────
    # Capture un ou deux mots (nom composé), s'arrête avant le prochain label.
    v = _extraire(texte, r'NOM')
    if v:
        # Garder seulement le premier token (évite de capturer le label suivant)
        nom = re.split(r'\s{2,}|\s+(?=[A-ZÀ-Ÿ]{2,}\s*[:\-])', v)[0].strip()
        if len(nom) >= 2:
            donnees['nom'] = nom.upper()

    # ── PRÉNOM ─────────────────────────────────────────────────────────────
    # Gère PRÉNOM / PRENOM / PRÉNOM(S) / PRENOM(S)
    v = _extraire(texte, r'PR[EÉ]NOM\(?S?\)?')
    if v:
        prenom = re.split(r'\s{2,}', v)[0].strip()
        if len(prenom) >= 2:
            donnees['prenom'] = prenom.title()

    # ── DATE DE NAISSANCE ──────────────────────────────────────────────────
    # Gère "DATE DE NAISSANCE :" (all-caps) et "Né(e) le" et "DDN"
    date_rx = re.compile(
        r'(?:DATE\s+DE\s+NAISSANCE|N[EÉ]E?\s+LE|DDN)\s*[:\-]?\s*'
        r'(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{4})',
        re.IGNORECASE,
    )
    m = date_rx.search(texte)
    if m:
        raw = m.group(1)
        parties = re.split(r'[\/\-\.]', raw)
        if len(parties) == 3:
            jj, mm, aaaa = parties
            donnees['date_naissance'] = f'{aaaa}-{mm.zfill(2)}-{jj.zfill(2)}'

    # ── SEXE ───────────────────────────────────────────────────────────────
    # "SEXE : M ☑ M ☐ F" → capture le 1er M ou F après le label.
    sexe_rx = re.compile(
        r'SEXE\s*[:\-]\s*(M(?:asculin)?|F(?:[eé]minin)?)',
        re.IGNORECASE,
    )
    m = sexe_rx.search(texte)
    if m:
        donnees['sexe'] = 'F' if m.group(1).upper().startswith('F') else 'M'

    # ── TÉLÉPHONE ──────────────────────────────────────────────────────────
    # Priorité : label explicite, sinon numéro international repéré dans le texte.
    tel_label_rx = re.compile(
        r'T[EÉ]L(?:[EÉ]PHONE?)?\s*[:\-]\s*'
        r'(\+?(?:237|33|229|225|221|228|226|223|224|227)\s?\d[\d\s]{5,14}|\b0\d{9}\b)',
        re.IGNORECASE,
    )
    m = tel_label_rx.search(texte)
    if m:
        tel = re.sub(r'\s', '', m.group(1))
        if len(tel) >= 8:
            donnees['telephone'] = tel
    else:
        tel_rx = re.compile(
            r'(\+?(?:237|33|229|225|221|228|226|223|224|227)\s?\d[\d\s]{5,14})'
        )
        m = tel_rx.search(texte)
        if m:
            tel = re.sub(r'\s', '', m.group(1))
            if len(tel) >= 8:
                donnees['telephone'] = tel

    # ── EMAIL ──────────────────────────────────────────────────────────────
    email_rx = re.compile(r'[\w.\-]+@[\w.\-]+\.\w{2,}')
    m = email_rx.search(texte)
    if m:
        donnees['email'] = m.group(0).lower()

    # ── GROUPE SANGUIN ─────────────────────────────────────────────────────
    gs_rx = re.compile(r'\b(AB[+\-]|A[+\-]|B[+\-]|O[+\-])\b')
    m = gs_rx.search(texte)
    if m:
        donnees['groupe_sanguin'] = m.group(1)

    # ── ADRESSE ────────────────────────────────────────────────────────────
    v = _extraire(texte, r'ADRESSE')
    if v and len(v) >= 5:
        donnees['adresse'] = v

    # ── ALLERGIES ──────────────────────────────────────────────────────────
    v = _extraire(texte, r'ALLERGI[EÈ]S?')
    if v and not re.match(r'^(?:aucune?|n[eé]ant|RAS|\/|-)$', v, re.IGNORECASE):
        donnees['allergies'] = v

    # ── PRATICIEN RÉFÉRENT ─────────────────────────────────────────────────
    # Ex: "PRATICIEN : Dr. NGONO Samuel" ou "MÉDECIN TRAITANT : Dupont Jean"
    praticien_rx = re.compile(
        r'(?:PRATICIEN|M[EÉ]DECIN\s+TRAITANT|CHIRURGIEN|DENTISTE)\s*[:\-]\s*'
        r'((?:Dr\.?\s*)?[A-Z\xC0-\xFF a-z\xe0-\xff][A-Z\xC0-\xFF a-z\xe0-\xff\s\.\-]{1,60}?)'
        r'(?=\s{3,}[A-Z\xC0-\xD6\xD8-\xDE]|\n|$)',
        re.IGNORECASE,
    )
    m = praticien_rx.search(texte)
    if m:
        praticien_v = m.group(1).strip()
        if len(praticien_v) >= 3:
            donnees['praticien_nom'] = praticien_v

    # ── Symptômes (détection par mots-clés) ────────────────────────────────
    symptomes_cles = [
        'douleur', 'sensibilité', 'gonflement', 'saignement', 'fracture',
        'carie', 'abcès', 'malaise', 'fièvre', 'fatigue', 'nausée',
        'migraine', 'céphalée', 'vertige', 'pulpite', 'pulpe',
    ]
    symptomes = [
        ligne.strip() for ligne in texte.split('\n')
        if any(mot in ligne.lower() for mot in symptomes_cles)
        and len(ligne.strip()) > 8
    ]

    # ── Traitements ─────────────────────────────────────────────────────────
    traitements_cles = [
        'obturation', 'extraction', 'détartrage', 'antibiotique',
        'anti-inflammatoire', 'analgésique', 'traitement', 'chirurgie',
        'radiographie', 'suivi',
    ]
    traitements = [
        ligne.strip() for ligne in texte.split('\n')
        if any(mot in ligne.lower() for mot in traitements_cles)
        and len(ligne.strip()) > 8
    ]

    return {
        "donnees_structurees": donnees,
        "symptomes": list(dict.fromkeys(symptomes)),   # déduplique
        "traitements": list(dict.fromkeys(traitements)),
        "notes": [],
        "dates": re.findall(r'\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2}', texte),
    }


# #EbaJioloLewis
