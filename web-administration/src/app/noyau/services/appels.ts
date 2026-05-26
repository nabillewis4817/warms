import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, map } from 'rxjs';
import { environment } from '../../../environments/environment';

export type StatutAppelUi = 'present' | 'absent' | 'retard' | 'en_attente';

export interface Appel {
  id: number;
  patient: number;
  patient_prenom?: string;
  patient_nom?: string;
  date_appel: string;
  statut: StatutAppelUi | string;
  statut_display?: string;
  motif_absence?: string;
  notes?: string;
  notes_appel?: string;
}

interface AppelApi {
  id: number;
  patient: number;
  patient_prenom?: string;
  patient_nom?: string;
  date_appel: string;
  statut: string;
  statut_display?: string;
  motif_absence?: string;
  notes_appel?: string;
}

@Injectable({
  providedIn: 'root',
})
export class AppelsService {
  private readonly baseUrl = `${environment.apiBaseUrl}/appels/`;

  constructor(private readonly http: HttpClient) {}

  private mapStatutToApi(statut: string): string {
    switch (statut) {
      case 'present':
        return 'present';
      case 'absent':
        return 'absent_non_justifie';
      case 'retard':
        return 'en_retard';
      case 'en_attente':
        return 'en_attente';
      default:
        return statut;
    }
  }

  private mapStatutFromApi(statut: string): StatutAppelUi | string {
    if (statut === 'absent_justifie' || statut === 'absent_non_justifie') return 'absent';
    if (statut === 'en_retard') return 'retard';
    if (statut === 'present') return 'present';
    if (statut === 'en_attente') return 'en_attente';
    return statut;
  }

  private mapFromApi(row: AppelApi): Appel {
    return {
      id: row.id,
      patient: row.patient,
      patient_prenom: row.patient_prenom,
      patient_nom: row.patient_nom,
      date_appel: row.date_appel,
      statut: this.mapStatutFromApi(row.statut),
      statut_display: row.statut_display,
      motif_absence: row.motif_absence,
      notes: row.notes_appel,
      notes_appel: row.notes_appel,
    };
  }

  private mapToApi(data: Partial<Appel>): Record<string, unknown> {
    const statutApi = this.mapStatutToApi(String(data.statut ?? 'present'));
    const payload: Record<string, unknown> = {
      patient: Number(data.patient),
      date_appel: data.date_appel,
      statut: statutApi,
      notes_appel: data.notes ?? data.notes_appel ?? '',
    };
    if (statutApi.startsWith('absent') && data.motif_absence) {
      payload['motif_absence'] = data.motif_absence;
      if (statutApi === 'absent_justifie') {
        payload['justificatif_fourni'] = true;
      }
    }
    if (statutApi === 'en_retard') {
      payload['duree_retard'] = '00:15:00';
    }
    return payload;
  }

  lister(): Observable<Appel[]> {
    return this.http.get<AppelApi[] | { results: AppelApi[] }>(this.baseUrl).pipe(
      map((rows) => {
        const list = Array.isArray(rows) ? rows : rows.results ?? [];
        return list.map((r) => this.mapFromApi(r));
      })
    );
  }

  detail(id: number): Observable<Appel> {
    return this.http.get<AppelApi>(`${this.baseUrl}${id}/`).pipe(map((r) => this.mapFromApi(r)));
  }

  creer(data: Partial<Appel>): Observable<Appel> {
    return this.http.post<AppelApi>(this.baseUrl, this.mapToApi(data)).pipe(map((r) => this.mapFromApi(r)));
  }

  modifier(id: number, data: Partial<Appel>): Observable<Appel> {
    return this.http.patch<AppelApi>(`${this.baseUrl}${id}/`, this.mapToApi(data)).pipe(map((r) => this.mapFromApi(r)));
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}${id}/`);
  }
}
