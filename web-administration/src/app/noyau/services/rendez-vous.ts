import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, map } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface RendezVous {
  id: number;
  patient: number;
  patient_prenom?: string;
  patient_nom?: string;
  date_heure: string;
  duree: number;
  motif: string;
  statut: 'programme' | 'confirme' | 'effectue' | 'annule' | 'absent' | 'reporte';
  notes?: string;
  debut?: string;
  fin?: string;
}

interface RendezVousApi {
  id: number;
  patient: number;
  patient_prenom?: string;
  patient_nom?: string;
  debut: string;
  fin: string;
  motif: string;
  statut: string;
  notes?: string;
}

@Injectable({
  providedIn: 'root',
})
export class RendezVousService {
  private readonly baseUrl = `${environment.apiBaseUrl}/rendez-vous/`;

  constructor(private readonly http: HttpClient) {}

  private mapFromApi(row: RendezVousApi): RendezVous {
    const debut = new Date(row.debut);
    const fin = new Date(row.fin);
    const dureeMs = Math.max(fin.getTime() - debut.getTime(), 15 * 60 * 1000);
    const duree = Math.round(dureeMs / 60000);
    const pad = (n: number) => String(n).padStart(2, '0');
    const date_heure = `${debut.getFullYear()}-${pad(debut.getMonth() + 1)}-${pad(debut.getDate())}T${pad(debut.getHours())}:${pad(debut.getMinutes())}`;
    return {
      id: row.id,
      patient: row.patient,
      patient_prenom: row.patient_prenom,
      patient_nom: row.patient_nom,
      date_heure,
      duree,
      motif: row.motif ?? '',
      statut: row.statut as RendezVous['statut'],
      notes: row.notes,
      debut: row.debut,
      fin: row.fin,
    };
  }

  private mapToApi(data: Partial<RendezVous>): Record<string, unknown> {
    const patientId = Number(data.patient);
    const dureeMin = Number(data.duree) || 30;
    const debut = data.date_heure ? new Date(data.date_heure) : new Date();
    const fin = new Date(debut.getTime() + dureeMin * 60000);
    return {
      patient: patientId,
      debut: debut.toISOString(),
      fin: fin.toISOString(),
      motif: data.motif ?? '',
      statut: data.statut ?? 'programme',
      notes: data.notes ?? '',
    };
  }

  lister(): Observable<RendezVous[]> {
    return this.http.get<RendezVousApi[] | { results: RendezVousApi[] }>(this.baseUrl).pipe(
      map((rows) => {
        const list = Array.isArray(rows) ? rows : rows.results ?? [];
        return list.map((r) => this.mapFromApi(r));
      })
    );
  }

  detail(id: number): Observable<RendezVous> {
    return this.http.get<RendezVousApi>(`${this.baseUrl}${id}/`).pipe(map((r) => this.mapFromApi(r)));
  }

  creer(data: Partial<RendezVous>): Observable<RendezVous> {
    return this.http.post<RendezVousApi>(this.baseUrl, this.mapToApi(data)).pipe(map((r) => this.mapFromApi(r)));
  }

  modifier(id: number, data: Partial<RendezVous>): Observable<RendezVous> {
    return this.http.patch<RendezVousApi>(`${this.baseUrl}${id}/`, this.mapToApi(data)).pipe(map((r) => this.mapFromApi(r)));
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}${id}/`);
  }
}
