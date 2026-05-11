import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class AppelsService {
  private readonly baseUrl = `${environment.apiBaseUrl}/appels`;

  constructor(private readonly http: HttpClient) {}

  lister(): Observable<Appel[]> {
    return this.http.get<Appel[]>(this.baseUrl);
  }

  detail(id: number): Observable<Appel> {
    return this.http.get<Appel>(`${this.baseUrl}/${id}/`);
  }

  creer(data: Partial<Appel>): Observable<Appel> {
    return this.http.post<Appel>(this.baseUrl, data);
  }

  modifier(id: number, data: Partial<Appel>): Observable<Appel> {
    return this.http.put<Appel>(`${this.baseUrl}/${id}/`, data);
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}/`);
  }
}

export interface Appel {
  id: number;
  patient: string;
  date_appel: string;
  statut: 'present' | 'absent' | 'retard';
  motif_absence?: string;
  notes?: string;
  created_at?: string;
  updated_at?: string;
}
