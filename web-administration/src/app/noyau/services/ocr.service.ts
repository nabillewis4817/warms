import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface OCRResult {
  text: string;
  confidence: number;
  words: OCRWord[];
}

export interface OCRWord {
  text: string;
  confidence: number;
  bbox: {
    x0: number;
    y0: number;
    x1: number;
    y1: number;
  };
}

export interface OCROptions {
  language?: string;
  pageSegMode?: string;
  engineMode?: string;
  whitelist?: string;
  blacklist?: string;
}

@Injectable({
  providedIn: 'root'
})
export class OCRService {
  private readonly apiUrl = 'http://127.0.0.1:8000/api/v1/ocr';

  constructor(private http: HttpClient) {}

  // Extraire le texte d'une image
  extraireTexte(imageFile: File, options?: OCROptions): Observable<OCRResult> {
    const formData = new FormData();
    formData.append('image', imageFile);
    
    if (options) {
      Object.entries(options).forEach(([key, value]) => {
        if (value) {
          formData.append(key, value);
        }
      });
    }

    return this.http.post<OCRResult>(`${this.apiUrl}/extract-text/`, formData);
  }

  // Extraire le texte depuis une URL d'image
  extraireTexteDepuisUrl(imageUrl: string, options?: OCROptions): Observable<OCRResult> {
    const payload = { image_url: imageUrl, ...options };
    return this.http.post<OCRResult>(`${this.apiUrl}/extract-from-url/`, payload);
  }

  // Obtenir les langues disponibles
  getLanguesDisponibles(): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/languages/`);
  }

  // Vérifier si Tesseract est installé
  verifierInstallation(): Observable<{ installed: boolean; version?: string; error?: string }> {
    return this.http.get<{ installed: boolean; version?: string; error?: string }>(`${this.apiUrl}/check-installation/`);
  }

  // Traiter un document médical (OCR spécialisé pour documents médicaux)
  traiterDocumentMedical(imageFile: File): Observable<{
    patient_info?: {
      nom?: string;
      prenom?: string;
      date_naissance?: string;
      numero_dossier?: string;
    };
    contenu: string;
    mots_cles: string[];
    type_document: string;
    confidence: number;
  }> {
    const formData = new FormData();
    formData.append('image', imageFile);
    formData.append('medical_mode', 'true');

    return this.http.post<any>(`${this.apiUrl}/process-medical-document/`, formData);
  }

  // Extraire des informations spécifiques d'un document
  extraireInformationsSpecifiques(imageFile: File, pattern: string): Observable<{
    matches: Array<{
      text: string;
      confidence: number;
      position: { x: number; y: number };
    }>;
  }> {
    const formData = new FormData();
    formData.append('image', imageFile);
    formData.append('pattern', pattern);

    return this.http.post<any>(`${this.apiUrl}/extract-pattern/`, formData);
  }

  // Améliorer la qualité de l'image avant OCR
  pretraiterImage(imageFile: File): Observable<Blob> {
    const formData = new FormData();
    formData.append('image', imageFile);

    return this.http.post(`${this.apiUrl}/preprocess-image/`, formData, { responseType: 'blob' });
  }

  // Obtenir les statistiques de reconnaissance
  getStatistiquesReconnaissance(imageFile: File): Observable<{
    total_words: number;
    recognized_words: number;
    confidence_average: number;
    confidence_distribution: {
      high: number;
      medium: number;
      low: number;
    };
  }> {
    const formData = new FormData();
    formData.append('image', imageFile);

    return this.http.post<any>(`${this.apiUrl}/recognition-stats/`, formData);
  }

  // Configurer Tesseract
  configurerTesseract(config: {
    datapath?: string;
    language?: string;
    oem?: number;
    psm?: number;
  }): Observable<{ success: boolean; message: string }> {
    return this.http.post<{ success: boolean; message: string }>(`${this.apiUrl}/configure/`, config);
  }

  // Télécharger des langues additionnelles
  telechargerLangue(langue: string): Observable<{ success: boolean; message: string }> {
    return this.http.post<{ success: boolean; message: string }>(`${this.apiUrl}/download-language/`, { language: langue });
  }
}
