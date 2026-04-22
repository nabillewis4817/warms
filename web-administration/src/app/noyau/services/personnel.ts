import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

export interface PersonnelCompte {
  id: number;
  username: string;
  role: string;
  first_name: string;
  last_name: string;
  est_valide_par_chirurgien?: boolean;
  is_active: boolean;
}

@Injectable({ providedIn: 'root' })
export class PersonnelService {
  private readonly baseUrl = 'http://127.0.0.1:8000/api/v1/personnel/utilisateurs';
  constructor(private readonly http: HttpClient) {}

  lister(): Observable<PersonnelCompte[]> {
    return this.http.get<PersonnelCompte[]>(`${this.baseUrl}/`);
  }

  creer(payload: any): Observable<PersonnelCompte> {
    return this.http.post<PersonnelCompte>(`${this.baseUrl}/`, payload);
  }

  valider(id: number): Observable<PersonnelCompte> {
    return this.http.post<PersonnelCompte>(`${this.baseUrl}/${id}/valider/`, {});
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}/`);
  }
}

// #EbaJioloLewis
