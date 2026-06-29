import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export type RecurrenceRappel = 'aucune' | 'quotidien' | 'hebdomadaire' | 'mensuel';

export interface Rappel {
  id: number;
  titre: string;
  message: string;
  date_heure: string;
  recurrence: RecurrenceRappel;
  actif: boolean;
  cree_le: string;
}

export type RappelPayload = Partial<Pick<Rappel, 'titre' | 'message' | 'date_heure' | 'recurrence' | 'actif'>>;

@Injectable({ providedIn: 'root' })
export class RappelsService {
  private readonly apiUrl = `${environment.apiBaseUrl}/rappels`;

  constructor(private readonly http: HttpClient) {}

  lister(): Observable<Rappel[]> {
    return this.http.get<Rappel[]>(`${this.apiUrl}/`);
  }

  creer(data: RappelPayload): Observable<Rappel> {
    return this.http.post<Rappel>(`${this.apiUrl}/`, data);
  }

  modifier(id: number, data: RappelPayload): Observable<Rappel> {
    return this.http.patch<Rappel>(`${this.apiUrl}/${id}/`, data);
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}/`);
  }
}
