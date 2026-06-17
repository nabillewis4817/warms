import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Avis {
  id: number;
  patient?: number;
  patient_nom?: string;
  patient_email?: string;
  type_avis: string;
  type_label?: string;
  note: number;
  titre?: string;
  commentaire?: string;
  points_positifs?: string;
  points_negatifs?: string;
  suggestions?: string;
  statut: string;
  statut_label?: string;
  reponse_personnel?: string;
  reponse_par?: number;
  reponse_par_nom?: string;
  date_reponse?: string;
  a_reponse?: boolean;
  est_recent?: boolean;
  nombre_signalements?: number;
  cree_le?: string;
  modifie_le?: string;
}

export interface AvisFilters {
  type_avis?: string;
  statut?: string;
  note_min?: number;
  note_max?: number;
  date_debut?: string;
  date_fin?: string;
  recherche?: string;
}

export interface AvisStatistiques {
  total_avis: number;
  note_moyenne: number;
  avis_recents: number;
  avec_reponse: number;
  par_type: Record<string, { count: number; avg_note: number }>;
  par_note: Record<string, number>;
  par_statut: Record<string, number>;
}

@Injectable({ providedIn: 'root' })
export class AvisService {
  private readonly apiUrl = `${environment.apiBaseUrl}/avis`;

  constructor(private readonly http: HttpClient) {}

  lister(filters?: AvisFilters): Observable<Avis[]> {
    let params = new HttpParams();
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          params = params.set(key, String(value));
        }
      });
    }
    return this.http.get<Avis[]>(`${this.apiUrl}/`, { params });
  }

  detail(id: number): Observable<Avis> {
    return this.http.get<Avis>(`${this.apiUrl}/${id}/`);
  }

  creer(data: Partial<Avis>): Observable<Avis> {
    return this.http.post<Avis>(`${this.apiUrl}/`, data);
  }

  modifier(id: number, data: Partial<Avis>): Observable<Avis> {
    return this.http.patch<Avis>(`${this.apiUrl}/${id}/`, data);
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}/`);
  }

  repondre(id: number, reponse: string): Observable<Avis> {
    return this.http.post<Avis>(`${this.apiUrl}/${id}/repondre/`, { reponse_personnel: reponse });
  }

  moderer(id: number, statut: string, motif?: string): Observable<Avis> {
    return this.http.post<Avis>(`${this.apiUrl}/${id}/moderer/`, { statut, motif_moderation: motif });
  }

  statistiques(): Observable<AvisStatistiques> {
    return this.http.get<AvisStatistiques>(`${this.apiUrl}/statistiques/`);
  }
}
