import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class TauxAbsenteismeService {
  private readonly baseUrl = `${environment.apiBaseUrl}/taux-absenteisme`;

  constructor(private readonly http: HttpClient) {}

  lister(): Observable<TauxAbsenteisme[]> {
    return this.http.get<TauxAbsenteisme[]>(this.baseUrl);
  }

  detail(id: number): Observable<TauxAbsenteisme> {
    return this.http.get<TauxAbsenteisme>(`${this.baseUrl}/${id}/`);
  }

  creer(data: Partial<TauxAbsenteisme>): Observable<TauxAbsenteisme> {
    return this.http.post<TauxAbsenteisme>(this.baseUrl, data);
  }

  modifier(id: number, data: Partial<TauxAbsenteisme>): Observable<TauxAbsenteisme> {
    return this.http.put<TauxAbsenteisme>(`${this.baseUrl}/${id}/`, data);
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}/`);
  }

  getStatistiques(): Observable<any> {
    return this.http.get<any>(`${this.baseUrl}/statistiques/`);
  }

  exporter(format: string): Observable<Blob> {
    return this.http.get(`${this.baseUrl}/exporter/?format=${format}`, {
      responseType: 'blob'
    });
  }
}

export interface TauxAbsenteisme {
  id: number;
  periode: string;
  service?: string;
  taux_general: number;
  taux_medecins: number;
  taux_infirmiers: number;
  taux_personnel: number;
  total_absences: number;
  total_employes: number;
  tendance: 'en_hausse' | 'en_baisse' | 'stable';
  created_at?: string;
  updated_at?: string;
}
