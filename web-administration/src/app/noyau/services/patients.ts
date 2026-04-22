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
}

export interface CreerPatientPayload {
  prenom: string;
  nom: string;
  telephone?: string;
  email?: string;
  date_naissance?: string;
  sexe?: string;
  adresse?: string;
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
}

// #EbaJioloLewis
