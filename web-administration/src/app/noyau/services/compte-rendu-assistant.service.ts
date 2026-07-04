import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, Subject } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface ContexteAction {
  type_action: 'consultation' | 'rendez_vous' | 'operation' | 'schema_dentaire' | 'autre';
  reference_id?: number;
  patient_id: number;
  patient_nom: string;
  patient_prenom: string;
  praticien_nom?: string;
  date?: string;
  motif?: string;
  observations?: string;
  diagnostic?: string;
  notes?: string;
  actes?: string[];
}

export interface CompteRendu {
  id: number;
  patient: number;
  patient_nom: string;
  patient_prenom: string;
  praticien?: number | null;
  praticien_nom: string;
  type_action: string;
  reference_id?: number | null;
  titre: string;
  contenu: string;
  contenu_ia_brut: string;
  genere_par_ia: boolean;
  cree_le: string;
  modifie_le: string;
}

export interface CompteRenduPayload {
  patient: number;
  type_action: string;
  reference_id?: number | null;
  titre: string;
  contenu: string;
  genere_par_ia: boolean;
}

@Injectable({ providedIn: 'root' })
export class CompteRenduAssistantService {
  private readonly http = inject(HttpClient);
  private readonly apiUrl = `${environment.apiBaseUrl}/comptes-rendus/`;

  private readonly _declencheur$ = new Subject<ContexteAction>();

  /** Observable que le composant modal écoute pour s'ouvrir. */
  readonly declencheur$ = this._declencheur$.asObservable();

  /** Appeler depuis n'importe quel composant après une action clinique complète. */
  declencherGeneration(contexte: ContexteAction): void {
    this._declencheur$.next(contexte);
  }

  /** Demande à l'IA de générer un compte-rendu (ne sauvegarde pas). */
  generer(contexte: ContexteAction): Observable<{ contenu: string; genere_par_ia: boolean }> {
    return this.http.post<{ contenu: string; genere_par_ia: boolean }>(
      `${this.apiUrl}generer/`,
      contexte,
    );
  }

  creer(payload: CompteRenduPayload): Observable<CompteRendu> {
    return this.http.post<CompteRendu>(this.apiUrl, payload);
  }

  modifier(id: number, payload: Partial<CompteRenduPayload>): Observable<CompteRendu> {
    return this.http.patch<CompteRendu>(`${this.apiUrl}${id}/`, payload);
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}${id}/`);
  }

  listerPatient(patientId: number): Observable<CompteRendu[]> {
    const params = new HttpParams().set('patient', patientId);
    return this.http.get<CompteRendu[]>(this.apiUrl, { params });
  }

  telechargerPdf(id: number): Observable<Blob> {
    return this.http.get(`${this.apiUrl}${id}/pdf/`, { responseType: 'blob' });
  }
}

// #EbaJioloLewis
