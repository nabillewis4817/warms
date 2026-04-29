import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface Patient {
  id: number;
  prenom: string;
  nom: string;
  telephone: string;
  email: string;
  numero_dossier?: string;
  qr_token?: string;
  statut_parcours?: string;
  actif: boolean;
  date_naissance?: string;
  sexe?: string;
  groupe_sanguin?: string;
  allergies?: string;
  adresse?: string;
  taille_cm?: string;
  poids_kg?: string;
  symptomes?: string;
  consultations_precedentes?: string;
  derniere_consultation_date?: string;
  derniere_consultation_lieu?: string;
  derniere_consultation_details?: string;
}

export interface CreerPatientPayload {
  prenom: string;
  nom: string;
  telephone?: string;
  email?: string;
  date_naissance?: string;
  age?: string;
  sexe?: string;
  adresse?: string;
  taille_cm?: string;
  poids_kg?: string;
  symptomes?: string;
  consultations_precedentes?: string;
  allergies?: string;
  groupe_sanguin?: string;
  derniere_consultation_date?: string;
  derniere_consultation_lieu?: string;
  derniere_consultation_details?: string;
  username_patient?: string;
  password_patient?: string;
}

@Injectable({
  providedIn: 'root',
})
export class Patients {
  private readonly baseUrl = 'http://127.0.0.1:8000/api/v1';

  constructor(private readonly http: HttpClient) {}

  lister(): Observable<Patient[]> {
    return this.http.get<Patient[]>(`${this.baseUrl}/patients/`);
  }

  creer(payload: CreerPatientPayload): Observable<Patient> {
    return this.http.post<Patient>(`${this.baseUrl}/patients/`, payload);
  }

  detail(id: number): Observable<Patient> {
    return this.http.get<Patient>(`${this.baseUrl}/patients/${id}/`);
  }

  modifier(id: number, payload: Partial<CreerPatientPayload>): Observable<Patient> {
    return this.http.patch<Patient>(`${this.baseUrl}/patients/${id}/`, payload);
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/patients/${id}/`);
  }

  archiver(id: number): Observable<Patient> {
    return this.http.post<Patient>(`${this.baseUrl}/patients/${id}/archiver/`, {});
  }

  desarchiver(id: number): Observable<Patient> {
    return this.http.post<Patient>(`${this.baseUrl}/patients/${id}/desarchiver/`, {});
  }

  supprimerAmeliore(id: number): Observable<{ message: string }> {
    return this.http.post<{ message: string }>(`${this.baseUrl}/patients/${id}/supprimer-ameliore/`, {});
  }

  exporter(filters?: any): Observable<Blob> {
    let params = '';
    if (filters) {
      const queryParams = new URLSearchParams();
      Object.entries(filters).forEach(([key, value]) => {
        if (value) {
          queryParams.append(key, String(value));
        }
      });
      params = `?${queryParams.toString()}`;
    }
    return this.http.get(`${this.baseUrl}/patients/exporter${params}`, { responseType: 'blob' });
  }
}

// #EbaJioloLewis
