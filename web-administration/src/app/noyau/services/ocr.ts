import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface OCRResult {
  texte_extrait: string;
  donnees_structurees?: {
    nom?: string;
    prenom?: string;
    date_naissance?: string;
    telephone?: string;
    email?: string;
    adresse?: string;
  };
  symptomes?: string[];
  traitements?: string[];
  confiance?: number;
}

@Injectable({
  providedIn: 'root'
})
export class OcrService {
  private readonly baseUrl = environment.apiBaseUrl;

  constructor(private http: HttpClient) {}

  extraireTexte(image: File): Observable<OCRResult> {
    const formData = new FormData();
    formData.append('image', image);

    return this.http.post<OCRResult>(`${this.baseUrl}/ia/ocr-carnet/`, formData);
  }

  // Méthode de secours si le backend n'est pas disponible
  extraireTexteSimulation(image: File): Observable<OCRResult> {
    return new Observable<OCRResult>((observer) => {
      // Simuler un traitement OCR avec un délai
      setTimeout(() => {
        const result: OCRResult = {
          texte_extrait: 'Texte extrait du document (simulation - endpoint backend non disponible)',
          donnees_structurees: {
            nom: 'DOE',
            prenom: 'John',
            date_naissance: '15/03/1985',
            telephone: '0123456789',
            email: 'john.doe@email.com'
          },
          confiance: 0.85
        };
        observer.next(result);
        observer.complete();
      }, 2000);
    });
  }
}
