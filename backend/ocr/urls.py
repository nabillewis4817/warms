from django.urls import path
from . import views

urlpatterns = [
    path('check-installation/', views.check_installation, name='ocr_check_installation'),
    path('languages/', views.get_languages, name='ocr_languages'),
    path('extract-text/', views.extract_text, name='ocr_extract_text'),
    path('extract-from-url/', views.extract_from_url, name='ocr_extract_from_url'),
    path('process-medical-document/', views.process_medical_document, name='ocr_process_medical'),
    path('extract-pattern/', views.extract_pattern, name='ocr_extract_pattern'),
    path('preprocess-image/', views.preprocess_image_endpoint, name='ocr_preprocess'),
    path('configure/', views.configure_tesseract, name='ocr_configure'),
]
