import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, timeout } from 'rxjs';

export interface WarmsIARequest {
  question: string;
  patient_id?: number;
}

export interface WarmsIAResponse {
  question: string;
  reponse: string;
  timestamp: string;
  patient_id?: number;
}

export interface WarmsIAInfo {
  nom: string;
  description: string;
  capacites: string[];
  limitations: string[];
}

@Injectable({
  providedIn: 'root'
})
export class WarmsIAService {
  private readonly baseUrl = 'http://127.0.0.1:8000/api/v1/ia';

  constructor(private http: HttpClient) {}

  /**
   * Pose une question à WARMS IA
   */
  poserQuestion(request: WarmsIARequest): Observable<WarmsIAResponse> {
    return this.http.post<WarmsIAResponse>(`${this.baseUrl}/warms-general/`, request).pipe(
      // Ajouter un timeout pour éviter les attentes infinies
      timeout(30000) // 30 secondes
    );
  }

  /**
   * Obtient les informations sur WARMS IA
   */
  getInformations(): Observable<WarmsIAInfo> {
    return this.http.get<WarmsIAInfo>(`${this.baseUrl}/warms-info/`);
  }
}
