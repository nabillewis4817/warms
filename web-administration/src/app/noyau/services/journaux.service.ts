import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, map } from 'rxjs';
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

interface JournalApiRow {
  id: number;
  date?: string;
  utilisateur?: string;
  action?: string;
  details?: string;
  type?: string;
  type_action?: string;
  icone?: string;
  cree_le?: string;
  message?: string;
  acteur_username?: string;
}

@Injectable({
  providedIn: 'root'
})
export class JournauxService {
  private readonly apiUrl = `${environment.apiBaseUrl}/personnel/journaux`;

  constructor(private http: HttpClient) {}

  private mapJournal(row: JournalApiRow): Journal {
    const type = row.type ?? row.type_action ?? 'systeme';
    return {
      id: row.id,
      date: row.date ?? (row.cree_le ? String(row.cree_le).slice(0, 16).replace('T', ' ') : ''),
      utilisateur: row.utilisateur ?? row.acteur_username ?? 'Système',
      action: row.action ?? 'Action',
      details: row.details ?? row.message ?? '',
      type,
      icone: row.icone ?? this.iconFromType(type),
    };
  }

  private iconFromType(type: string): string {
    const icons: Record<string, string> = {
      patient: 'bi-person-plus',
      consultation: 'bi-clipboard2',
      rendez_vous: 'bi-calendar-check',
      personnel: 'bi-people',
      systeme: 'bi-gear',
      modification: 'bi-pencil',
      suppression: 'bi-trash',
      connexion: 'bi-box-arrow-in-right',
    };
    return icons[type] ?? 'bi-circle';
  }

  getJournaux(filters?: JournalFilters): Observable<Journal[]> {
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
    const url = params ? `${this.apiUrl}/${params}` : `${this.apiUrl}/`;
    return this.http.get<JournalApiRow[]>(url).pipe(
      map((rows) => (rows ?? []).map((row) => this.mapJournal(row)))
    );
  }

  exporterJournaux(filters?: JournalFilters): Observable<Blob> {
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
    const url = params ? `${this.apiUrl}/export/${params}` : `${this.apiUrl}/export/`;
    return this.http.get(url, { responseType: 'blob' });
  }

  getTypesJournaux(): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/types/`);
  }

  getUtilisateurs(): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/utilisateurs/`);
  }

  getStatistiques(): Observable<{ total: number; par_type: Record<string, number> }> {
    return this.http.get<{ total: number; par_type: Record<string, number> }>(
      `${environment.apiBaseUrl}/journaux/statistiques/`
    );
  }
}
