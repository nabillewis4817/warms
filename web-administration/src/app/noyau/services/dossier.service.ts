import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Dossier {
  id: string;
  numero_dossier: string;
  notes_medicales: string;
  antecedents: string;
  allergies: string;
  cree_le: string;
  modifie_le: string;
}

export interface DossierPayload {
  notes_medicales?: string;
  antecedents?: string;
  allergies?: string;
}

@Injectable({
  providedIn: 'root',
})
export class DossierService {
  private readonly baseUrl = `${environment.apiBaseUrl}/dossiers`;

  constructor(private readonly http: HttpClient) {}

  detail(id: string): Observable<Dossier> {
    return this.http.get<Dossier>(`${this.baseUrl}/${id}/`);
  }

  modifier(id: string, payload: DossierPayload): Observable<Dossier> {
    return this.http.patch<Dossier>(`${this.baseUrl}/${id}/`, payload);
  }
}

// #EbaJioloLewis
