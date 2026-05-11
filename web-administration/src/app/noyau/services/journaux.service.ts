import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Journal {
  id: number;
  date: string;
  utilisateur: string;
  action: string;
  details: string;
  type: string;
  icone: string;
}

export interface JournalFilters {
  recherche?: string;
  dateDebut?: string;
  dateFin?: string;
  type?: string;
  utilisateur?: string;
}

@Injectable({
  providedIn: 'root'
})
export class JournauxService {
  private readonly apiUrl = `${environment.apiBaseUrl}/journaux`;

  constructor(private http: HttpClient) {}

  // Obtenir tous les journaux avec filtres
  getJournaux(filters?: JournalFilters): Observable<Journal[]> {
    let params = '';
    if (filters) {
      const queryParams = new URLSearchParams();
      Object.entries(filters).forEach(([key, value]) => {
        if (value) {
          queryParams.append(key, value);
        }
      });
      params = `?${queryParams.toString()}`;
    }
    return this.http.get<Journal[]>(`${this.apiUrl}${params}`);
  }

  // Exporter les journaux
  exporterJournaux(filters?: JournalFilters): Observable<Blob> {
    let params = '';
    if (filters) {
      const queryParams = new URLSearchParams();
      Object.entries(filters).forEach(([key, value]) => {
        if (value) {
          queryParams.append(key, value);
        }
      });
      params = `?${queryParams.toString()}`;
    }
    return this.http.get(`${this.apiUrl}/exporter${params}`, { responseType: 'blob' });
  }

  // Obtenir les types de journaux disponibles
  getTypesJournaux(): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/types`);
  }

  // Obtenir les utilisateurs pour les filtres
  getUtilisateurs(): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/utilisateurs`);
  }

  // Obtenir les statistiques des journaux
  getStatistiques(): Observable<any> {
    return this.http.get(`${this.apiUrl}/statistiques`);
  }
}
