import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

export interface Patient {
  id: number;
  prenom: string;
  nom: string;
  telephone: string;
  email: string;
  numero_dossier?: string;
  dossier_id?: string;
  qr_token?: string;
  statut_parcours?: string;
  actif: boolean;
  supprime_le?: string | null;
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
  private readonly baseUrl = environment.apiBaseUrl;

  constructor(private readonly http: HttpClient) {}

  lister(actifsSeulement = true): Observable<Patient[]> {
    return this.http
      .get<Patient[] | { results: Patient[] }>(`${this.baseUrl}/patients/`)
      .pipe(
        map((response) => {
          const rows = Array.isArray(response) ? response : response.results ?? [];
          return actifsSeulement ? rows.filter((p) => p.actif !== false) : rows;
        })
      );
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

  archiver(id: number): Observable<Patient> {
    return this.http.post<Patient>(`${this.baseUrl}/patients/${id}/archiver/`, {});
  }

  desarchiver(id: number): Observable<Patient> {
    return this.http.post<Patient>(`${this.baseUrl}/patients/${id}/desarchiver/`, {});
  }

  /** Liste des patients mis à la corbeille (suppression douce). */
  listerCorbeille(): Observable<Patient[]> {
    return this.http
      .get<Patient[] | { results: Patient[] }>(`${this.baseUrl}/patients/corbeille/`)
      .pipe(map((response) => (Array.isArray(response) ? response : response.results ?? [])));
  }

  /** Déplace un patient vers la corbeille (réversible). */
  mettreCorbeille(id: number): Observable<{ id: number; detail: string }> {
    return this.http.post<{ id: number; detail: string }>(`${this.baseUrl}/patients/${id}/corbeille/`, {});
  }

  /** Restaure un patient depuis la corbeille. */
  restaurerDeCorbeille(id: number): Observable<Patient> {
    return this.http.post<Patient>(`${this.baseUrl}/patients/${id}/restaurer-corbeille/`, {});
  }

  /** Supprime définitivement un patient (depuis la corbeille). Action irréversible. */
  supprimerDefinitivement(id: number): Observable<{ id: number; detail: string }> {
    return this.http.delete<{ id: number; detail: string }>(
      `${this.baseUrl}/patients/${id}/supprimer-definitivement/`
    );
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
