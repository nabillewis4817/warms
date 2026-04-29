from django.apps import AppConfig


class OcrConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'ocr'
    
    def ready(self):
        # Vérifier l'installation de Tesseract au démarrage
        try:
            import pytesseract
            import os
            
            if os.name == 'nt':
                tesseract_path = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
                if os.path.exists(tesseract_path):
                    pytesseract.pytesseract.tesseract_cmd = tesseract_path
        except ImportError:
            print("AVERTISSEMENT: pytesseract n'est pas installé. Veuillez installer avec: pip install pytesseract")
        except Exception as e:
            print(f"AVERTISSEMENT: Erreur lors de la configuration de Tesseract: {e}")
