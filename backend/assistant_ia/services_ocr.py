from typing import Tuple

import pytesseract
from PIL import Image
from django.conf import settings
from django.core.files.uploadedfile import InMemoryUploadedFile

# TESSDATA_PREFIX (langues) est posée par gestion_cabinet.settings au
# démarrage. Seul le chemin du binaire reste à configurer ici (utile sur
# Windows où l'installeur ne met pas toujours à jour le PATH des process
# déjà lancés).
_tesseract_path = getattr(settings, "TESSERACT_PATH", None)
if _tesseract_path:
    pytesseract.pytesseract.tesseract_cmd = _tesseract_path


class TesseractIndisponible(Exception):
    """Levée quand le binaire Tesseract OCR n'est pas accessible sur le système."""


def extraire_texte_image(image_file: InMemoryUploadedFile, lang: str = "fra") -> Tuple[str, float]:
    """
    Extrait le texte d'une image avec Tesseract OCR.

    Args:
        image_file: Fichier image uploadé
        lang: Code langue pour Tesseract ('fra' pour français)

    Returns:
        Tuple (texte_extrait, confiance) où confiance est un taux réel
        (moyenne des scores de confiance Tesseract par mot détecté, 0.0-1.0).

    Raises:
        TesseractIndisponible: si le binaire Tesseract n'est pas installé/accessible.
    """
    try:
        pytesseract.get_tesseract_version()
    except Exception as e:
        raise TesseractIndisponible(
            "Le moteur Tesseract OCR n'est pas installé ou accessible sur le serveur."
        ) from e

    image = Image.open(image_file)
    image = _pretraiter_image(image)

    texte = pytesseract.image_to_string(image, lang=lang, config="--psm 6")

    donnees = pytesseract.image_to_data(image, lang=lang, config="--psm 6", output_type=pytesseract.Output.DICT)
    confiances = [float(c) for c in donnees.get("conf", []) if c not in ("-1", -1) and float(c) >= 0]
    confiance = (sum(confiances) / len(confiances) / 100) if confiances else 0.0

    return texte.strip(), confiance


def _pretraiter_image(image: Image.Image) -> Image.Image:
    """
    Améliore la qualité de l'image pour un meilleur OCR.
    """
    # Convertir en niveaux de gris si nécessaire
    if image.mode != 'L':
        image = image.convert('L')
    
    # Augmenter le contraste
    from PIL import ImageEnhance
    enhancer = ImageEnhance.Contrast(image)
    image = enhancer.enhance(2.0)
    
    # Binarisation (seuil adaptatif)
    image = image.point(lambda x: 0 if x < 128 else 255, '1')
    
    return image


def analyser_carnet_medical(texte: str) -> dict:
    """
    Analyse le texte extrait d'un carnet médical pour structurer les informations.
    
    Args:
        texte: Texte brut extrait par OCR
    
    Returns:
        Dictionnaire avec les informations structurées
    """
    if not texte:
        return {"erreur": "Aucun texte à analyser"}
    
    result = {
        "texte_brut": texte,
        "donnees_structurees": {},
        "symptomes": [],
        "traitements": [],
        "notes": [],
        "dates": [],
    }
    
    lignes = texte.split('\n')
    
    # Extraction des informations personnelles
    donnees_perso = {}
    
    for ligne in lignes:
        ligne = ligne.strip()
        if not ligne:
            continue
            
        # Extraction du nom et prénom
        import re
        # Patterns pour noms/prénoms
        nom_patterns = [
            r'Nom\s*[:]\s*([A-Za-zÀ-ÿ\s-]+)',
            r'Nom\s*([A-Za-zÀ-ÿ\s-]+)',
            r'Patient\s*[:]\s*([A-Za-zÀ-ÿ\s-]+)',
        ]
        
        prenom_patterns = [
            r'Prénom\s*[:]\s*([A-Za-zÀ-ÿ\s-]+)',
            r'Prénom\s*([A-Za-zÀ-ÿ\s-]+)',
        ]
        
        for pattern in nom_patterns:
            match = re.search(pattern, ligne, re.IGNORECASE)
            if match:
                donnees_perso['nom'] = match.group(1).strip().upper()
                break
                
        for pattern in prenom_patterns:
            match = re.search(pattern, ligne, re.IGNORECASE)
            if match:
                donnees_perso['prenom'] = match.group(1).strip().capitalize()
                break
        
        # Extraction de la date de naissance
        date_naissance_patterns = [
            r'Date\s*de\s*naissance\s*[:]\s*(\d{2}/\d{2}/\d{4})',
            r'Né\([e]?\)\s*le\s*(\d{2}/\d{2}/\d{4})',
            r'DDN\s*[:]\s*(\d{2}/\d{2}/\d{4})',
        ]
        
        for pattern in date_naissance_patterns:
            match = re.search(pattern, ligne, re.IGNORECASE)
            if match:
                donnees_perso['date_naissance'] = match.group(1)
                break
        
        # Extraction du téléphone
        telephone_patterns = [
            r'Téléphone\s*[:]\s*([0-9\s\.\-]+)',
            r'Tel\s*[:]\s*([0-9\s\.\-]+)',
            r'(\d{2}[\s\.\-]?\d{2}[\s\.\-]?\d{2}[\s\.\-]?\d{2}[\s\.\-]?\d{2})',
        ]
        
        for pattern in telephone_patterns:
            match = re.search(pattern, ligne, re.IGNORECASE)
            if match:
                tel = re.sub(r'[\s\.\-]', '', match.group(1))
                if len(tel) == 10 and tel.startswith('0'):
                    donnees_perso['telephone'] = tel
                break
        
        # Extraction de l'email
        email_patterns = [
            r'Email\s*[:]\s*([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
            r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
        ]
        
        for pattern in email_patterns:
            match = re.search(pattern, ligne, re.IGNORECASE)
            if match:
                donnees_perso['email'] = match.group(1).lower()
                break
        
        # Extraction de l'adresse
        adresse_patterns = [
            r'Adresse\s*[:]\s*([0-9]+\s+[A-Za-zÀ-ÿ\s\'-]+)',
            r'([0-9]+\s+[A-Za-zÀ-ÿ\s\'-]+,\s*[0-9]+\s+[A-Za-zÀ-ÿ\s\'-]+)',
        ]
        
        for pattern in adresse_patterns:
            match = re.search(pattern, ligne, re.IGNORECASE)
            if match:
                donnees_perso['adresse'] = match.group(1).strip()
                break
            
        # Extraction des symptômes (mots clés médicaux)
        symptomes_cles = [
            'douleur', 'sensibilité', 'gonflement', 'saignement', 'fracture', 'carie', 'abcès',
            'malaise', 'fièvre', 'fatigue', 'nausée', 'vomissement', 'toux', 'essoufflement',
            'migraine', 'céphalée', 'vertige', 'éruption', 'démangeaison', 'brûlure'
        ]
        
        if any(mot in ligne.lower() for mot in symptomes_cles):
            result["symptomes"].append(ligne)
        
        # Extraction des traitements médicaux
        traitements_cles = [
            'antibiotique', 'anti-inflammatoire', 'analgésique', 'détartrage', 'obturation', 'extraction',
            'médicament', 'traitement', 'thérapie', 'chirurgie', 'radiographie', 'injection',
            'pansement', 'suture', 'biopsie', 'endoscopie', 'échographie'
        ]
        
        if any(mot in ligne.lower() for mot in traitements_cles):
            result["traitements"].append(ligne)
        
        # Extraction des dates (format JJ/MM/AAAA ou AAAA-MM-JJ)
        dates = re.findall(r'\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2}', ligne)
        result["dates"].extend(dates)
        
        # Notes générales (lignes informatives)
        if len(ligne) > 10 and ligne not in result["symptomes"] and ligne not in result["traitements"]:
            result["notes"].append(ligne)
    
    # Ajouter les données personnelles structurées si trouvées
    if donnees_perso:
        result["donnees_structurees"] = donnees_perso
    
    return result


#EbaJioloLewis
