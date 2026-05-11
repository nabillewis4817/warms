import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface VueGeneraleStats {
  kpis: {
    consultations_30j: number;
    rendez_vous_30j: number;
    absents_30j: number;
    taux_absenteisme_30j: number;
  };
  series: {
    consultations_par_jour: { jour: string; total: number }[];
    consultations_par_praticien: {
      praticien_id: number | null;
      praticien__first_name: string | null;
      praticien__last_name: string | null;
      total: number;
    }[];
    pathologies_tendance: { diagnostic: string; total: number }[];
    actes_frequents: { libelle: string; total: number }[];
  };
}

@Injectable({
  providedIn: 'root',
})
export class StatistiquesService {
  private readonly baseUrl = `${environment.apiBaseUrl}/statistiques`;
  constructor(private readonly http: HttpClient) {}

  vueGenerale(): Observable<VueGeneraleStats> {
    return this.http.get<VueGeneraleStats>(`${this.baseUrl}/vue-generale/`);
  }
}

// #EbaJioloLewis
