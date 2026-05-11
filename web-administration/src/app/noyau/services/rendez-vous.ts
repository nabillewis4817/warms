import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class RendezVousService {
  private readonly baseUrl = `${environment.apiBaseUrl}/rendez-vous`;

  constructor(private readonly http: HttpClient) {}

  lister(): Observable<RendezVous[]> {
    return this.http.get<RendezVous[]>(this.baseUrl);
  }

  detail(id: number): Observable<RendezVous> {
    return this.http.get<RendezVous>(`${this.baseUrl}/${id}/`);
  }

  creer(data: Partial<RendezVous>): Observable<RendezVous> {
    return this.http.post<RendezVous>(this.baseUrl, data);
  }

  modifier(id: number, data: Partial<RendezVous>): Observable<RendezVous> {
    return this.http.put<RendezVous>(`${this.baseUrl}/${id}/`, data);
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}/`);
  }
}

export interface RendezVous {
  id: number;
  patient: string; // ID du patient sous forme de string pour le formulaire
  date_heure: string;
  duree: number;
  motif: string;
  statut: 'programme' | 'en_cours' | 'termine' | 'annule';
  notes?: string;
  created_at?: string;
  updated_at?: string;
}
