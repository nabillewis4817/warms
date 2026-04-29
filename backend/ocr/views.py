import os
import tempfile
import json
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.conf import settings
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
import cv2
import numpy as np
from PIL import Image
import pytesseract
import re
from datetime import datetime

# Configuration Tesseract
TESSERACT_CMD = r'C:\Program Files\Tesseract-OCR\tesseract.exe' if os.name == 'nt' else 'tesseract'

def check_tesseract_installation():
    """Vérifie si Tesseract est installé"""
    try:
        if os.name == 'nt' and os.path.exists(TESSERACT_CMD):
            pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD
        
        version = pytesseract.get_tesseract_version()
        return True, str(version)
    except Exception as e:
        return False, str(e)

def preprocess_image(image_path):
    """Prétraite une image pour améliorer la reconnaissance OCR"""
    # Charger l'image
    img = cv2.imread(image_path)
    
    # Convertir en niveaux de gris
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Réduction du bruit
    denoised = cv2.fastNlMeansDenoising(gray)
    
    # Binarisation adaptative
    binary = cv2.adaptiveThreshold(denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
    
    # Amélioration du contraste
    enhanced = cv2.equalizeHist(binary)
    
    return enhanced

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_installation(request):
    """Vérifie l'installation de Tesseract"""
    installed, version_or_error = check_tesseract_installation()
    
    return Response({
        'installed': installed,
        'version': version_or_error if installed else None,
        'error': version_or_error if not installed else None
    })

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_languages(request):
    """Obtient la liste des langues disponibles"""
    if not check_tesseract_installation()[0]:
        return Response({'error': 'Tesseract n\'est pas installé'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    
    try:
        languages = pytesseract.get_languages(config='')
        return Response(languages)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def extract_text(request):
    """Extrait le texte d'une image"""
    if not check_tesseract_installation()[0]:
        return Response({'error': 'Tesseract n\'est pas installé'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    
    if 'image' not in request.FILES:
        return Response({'error': 'Aucune image fournie'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        image_file = request.FILES['image']
        
        # Créer un fichier temporaire
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
            for chunk in image_file.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name
        
        # Prétraiter l'image
        processed_image = preprocess_image(temp_path)
        
        # Sauvegarder l'image traitée
        processed_path = temp_path.replace('.png', '_processed.png')
        cv2.imwrite(processed_path, processed_image)
        
        # Options OCR
        custom_config = r'--oem 3 --psm 6'
        lang = request.POST.get('language', 'fra')
        
        # Extraire le texte
        text = pytesseract.image_to_string(processed_image, lang=lang, config=custom_config)
        
        # Extraire les données détaillées
        data = pytesseract.image_to_data(processed_image, lang=lang, config=custom_config, output_type=pytesseract.Output.DICT)
        
        # Calculer la confiance moyenne
        confidences = [int(conf) for conf in data['conf'] if int(conf) > 0]
        avg_confidence = sum(confidences) / len(confidences) if confidences else 0
        
        # Extraire les mots avec leurs positions
        words = []
        for i in range(len(data['text'])):
            if int(data['conf'][i]) > 0:
                words.append({
                    'text': data['text'][i],
                    'confidence': int(data['conf'][i]),
                    'bbox': {
                        'x0': data['left'][i],
                        'y0': data['top'][i],
                        'x1': data['left'][i] + data['width'][i],
                        'y1': data['top'][i] + data['height'][i]
                    }
                })
        
        # Nettoyer les fichiers temporaires
        os.unlink(temp_path)
        os.unlink(processed_path)
        
        return Response({
            'text': text.strip(),
            'confidence': avg_confidence,
            'words': words
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def extract_from_url(request):
    """Extrait le texte depuis une URL d'image"""
    try:
        data = json.loads(request.body)
        image_url = data.get('image_url')
        
        if not image_url:
            return Response({'error': 'URL d\'image non fournie'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Télécharger l'image
        import requests
        response = requests.get(image_url)
        response.raise_for_status()
        
        # Créer un fichier temporaire
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
            temp_file.write(response.content)
            temp_path = temp_file.name
        
        # Traiter l'image
        processed_image = preprocess_image(temp_path)
        processed_path = temp_path.replace('.png', '_processed.png')
        cv2.imwrite(processed_path, processed_image)
        
        # Extraire le texte
        custom_config = r'--oem 3 --psm 6'
        lang = data.get('language', 'fra')
        
        text = pytesseract.image_to_string(processed_image, lang=lang, config=custom_config)
        
        # Nettoyer les fichiers temporaires
        os.unlink(temp_path)
        os.unlink(processed_path)
        
        return Response({
            'text': text.strip(),
            'confidence': 95.0,  # Estimation
            'words': []
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def process_medical_document(request):
    """Traite un document médical avec OCR spécialisé"""
    if not check_tesseract_installation()[0]:
        return Response({'error': 'Tesseract n\'est pas installé'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    
    if 'image' not in request.FILES:
        return Response({'error': 'Aucune image fournie'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        image_file = request.FILES['image']
        
        # Créer un fichier temporaire
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
            for chunk in image_file.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name
        
        # Prétraiter l'image
        processed_image = preprocess_image(temp_path)
        processed_path = temp_path.replace('.png', '_processed.png')
        cv2.imwrite(processed_path, processed_image)
        
        # Extraire le texte
        custom_config = r'--oem 3 --psm 6'
        text = pytesseract.image_to_string(processed_image, config=custom_config)
        
        # Extraire les informations médicales avec des regex
        patient_info = {}
        
        # Nom et prénom
        nom_pattern = r'(?i)(nom|patient)[:\s]+([A-Za-zÀ-ÿ\s]+)'
        nom_match = re.search(nom_pattern, text)
        if nom_match:
            patient_info['nom'] = nom_match.group(2).strip()
        
        # Date de naissance
        date_pattern = r'(\d{2}\/\d{2}\/\d{4}|\d{4}-\d{2}-\d{2})'
        date_match = re.search(date_pattern, text)
        if date_match:
            patient_info['date_naissance'] = date_match.group(1)
        
        # Numéro de dossier
        dossier_pattern = r'(?i)(dossier|n°|numéro)[:\s]+([A-Z0-9-]+)'
        dossier_match = re.search(dossier_pattern, text)
        if dossier_match:
            patient_info['numero_dossier'] = dossier_match.group(2)
        
        # Mots-clés médicaux
        medical_keywords = ['consultation', 'ordonnance', 'analyse', 'radiographie', 'prescription', 'diagnostic']
        mots_cles = [kw for kw in medical_keywords if kw.lower() in text.lower()]
        
        # Déterminer le type de document
        if 'ordonnance' in text.lower():
            type_document = 'ordonnance'
        elif 'analyse' in text.lower() or 'résultat' in text.lower():
            type_document = 'analyse'
        elif 'radiographie' in text.lower() or 'radio' in text.lower():
            type_document = 'radiographie'
        elif 'consultation' in text.lower():
            type_document = 'consultation'
        else:
            type_document = 'document_medical'
        
        # Nettoyer les fichiers temporaires
        os.unlink(temp_path)
        os.unlink(processed_path)
        
        return Response({
            'patient_info': patient_info,
            'contenu': text.strip(),
            'mots_cles': mots_cles,
            'type_document': type_document,
            'confidence': 95.0
        })
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def extract_pattern(request):
    """Extrait des informations spécifiques basées sur un pattern"""
    if not check_tesseract_installation()[0]:
        return Response({'error': 'Tesseract n\'est pas installé'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    
    if 'image' not in request.FILES:
        return Response({'error': 'Aucune image fournie'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        image_file = request.FILES['image']
        pattern = request.POST.get('pattern', '')
        
        # Créer un fichier temporaire
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
            for chunk in image_file.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name
        
        # Prétraiter l'image
        processed_image = preprocess_image(temp_path)
        processed_path = temp_path.replace('.png', '_processed.png')
        cv2.imwrite(processed_path, processed_image)
        
        # Extraire les données détaillées
        data = pytesseract.image_to_data(processed_image, output_type=pytesseract.Output.DICT)
        
        # Chercher les correspondances
        matches = []
        for i in range(len(data['text'])):
            if int(data['conf'][i]) > 0 and re.search(pattern, data['text'][i]):
                matches.append({
                    'text': data['text'][i],
                    'confidence': int(data['conf'][i]),
                    'position': {
                        'x': data['left'][i],
                        'y': data['top'][i]
                    }
                })
        
        # Nettoyer les fichiers temporaires
        os.unlink(temp_path)
        os.unlink(processed_path)
        
        return Response({'matches': matches})
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def preprocess_image_endpoint(request):
    """Prétraite une image et la retourne"""
    if 'image' not in request.FILES:
        return Response({'error': 'Aucune image fournie'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        image_file = request.FILES['image']
        
        # Créer un fichier temporaire
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as temp_file:
            for chunk in image_file.chunks():
                temp_file.write(chunk)
            temp_path = temp_file.name
        
        # Prétraiter l'image
        processed_image = preprocess_image(temp_path)
        processed_path = temp_path.replace('.png', '_processed.png')
        cv2.imwrite(processed_path, processed_image)
        
        # Lire l'image traitée et la retourner
        with open(processed_path, 'rb') as f:
            image_data = f.read()
        
        # Nettoyer les fichiers temporaires
        os.unlink(temp_path)
        os.unlink(processed_path)
        
        return HttpResponse(image_data, content_type='image/png')
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def configure_tesseract(request):
    """Configure Tesseract"""
    try:
        config = request.data
        
        # Configurer le chemin Tesseract si nécessaire
        if 'datapath' in config and os.name == 'nt':
            pytesseract.pytesseract.tesseract_cmd = config['datapath']
        
        return Response({
            'success': True,
            'message': 'Configuration mise à jour avec succès'
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'message': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
