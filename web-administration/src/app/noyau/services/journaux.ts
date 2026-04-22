import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface EntreeJournal {
  id: number;
  action: string;
  objet_type: string;
  objet_id: string;
  message: string;
  cree_le: string;
  acteur_username?: string;
}

@Injectable({
  providedIn: 'root',
})
export class Journaux {
  private readonly baseUrl = 'http://127.0.0.1:8000/api/v1';
  constructor(private readonly http: HttpClient) {}

  lister(): Observable<EntreeJournal[]> {
    return this.http.get<EntreeJournal[]>(`${this.baseUrl}/journaux/`);
  }
}

// #EbaJioloLewis
