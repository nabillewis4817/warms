import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, map } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface TauxAbsenteisme {
  id: number;
  periode_debut: string;
  periode_fin: string;
  type_periode: string;
  praticien?: number | null;
  praticien_nom?: string;
  total_appels: number;
  total_presents: number;
  total_absents: number;
  taux_absenteisme: number;
  taux_presence: number;
  taux_retard: number;
  cree_le?: string;
}

export interface CalculerTauxPayload {
  periode_debut: string;
  periode_fin: string;
  type_periode?: string;
  praticien_id?: number;
}

@Injectable({
  providedIn: 'root',
})
export class TauxAbsenteismeService {
  private readonly baseUrl = `${environment.apiBaseUrl}/taux-absenteisme/`;

  constructor(private readonly http: HttpClient) {}

  lister(): Observable<TauxAbsenteisme[]> {
    return this.http.get<TauxAbsenteisme[] | { results: TauxAbsenteisme[] }>(this.baseUrl).pipe(
      map((rows) => (Array.isArray(rows) ? rows : rows.results ?? []))
    );
  }

  detail(id: number): Observable<TauxAbsenteisme> {
    return this.http.get<TauxAbsenteisme>(`${this.baseUrl}${id}/`);
  }

  calculer(payload: CalculerTauxPayload): Observable<TauxAbsenteisme> {
    return this.http.post<TauxAbsenteisme>(`${this.baseUrl}calculer/`, payload);
  }

  historique(typePeriode = 'mois', limit = 12): Observable<TauxAbsenteisme[]> {
    return this.http.get<TauxAbsenteisme[] | { results: TauxAbsenteisme[] }>(
      `${this.baseUrl}historique/`,
      { params: { type_periode: typePeriode, limit: String(limit) } }
    ).pipe(map((rows) => (Array.isArray(rows) ? rows : rows.results ?? [])));
  }

  getStatistiques(): Observable<Record<string, number>> {
    return this.http.get<Record<string, number>>(`${this.baseUrl}statistiques/`);
  }
}
