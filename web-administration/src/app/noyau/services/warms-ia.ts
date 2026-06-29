import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, timeout } from 'rxjs';
import { environment } from '../../../environments/environment';

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

export interface ActionAssistant {
  name: string;
  input: Record<string, any>;
}

export interface EffetAssistant {
  type: 'naviguer' | 'changer_theme';
  chemin?: string;
  mode?: 'clair' | 'sombre';
}

export type ReponseCommandeAssistant =
  | { type: 'reponse'; texte: string }
  | { type: 'confirmation'; action: ActionAssistant; description: string }
  | { type: 'resultat'; succes: boolean; message: string; effet?: EffetAssistant };

@Injectable({
  providedIn: 'root'
})
export class WarmsIAService {
  private readonly baseUrl = `${environment.apiBaseUrl}/ia`;

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

  /**
   * Envoie un message libre à l'assistant : peut renvoyer une réponse texte
   * classique, ou une action CRUD à confirmer (voir confirmerAction).
   */
  envoyerCommande(message: string): Observable<ReponseCommandeAssistant> {
    return this.http
      .post<ReponseCommandeAssistant>(`${this.baseUrl}/commande/`, { message })
      .pipe(timeout(30000));
  }

  /**
   * Exécute réellement une action précédemment proposée par l'assistant.
   */
  confirmerAction(action: ActionAssistant): Observable<ReponseCommandeAssistant> {
    return this.http
      .post<ReponseCommandeAssistant>(`${this.baseUrl}/commande/`, { action, confirmer: true })
      .pipe(timeout(30000));
  }
}
