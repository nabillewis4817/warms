import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface MetriqueDetaillee {
  nom: string;
  valeur: string | number;
  periode: string;
  tendance: number;
}

export interface CategoriePatient {
  nom: string;
  nombre: number;
  couleur: string;
}

export interface RendezVousParMois {
  mois: string;
  nombre: number;
}

export interface ConsultationParPraticien {
  praticien_id: number | null;
  praticien_nom: string;
  total: number;
}

export interface PathologieTendance {
  diagnostic: string;
  total: number;
}

export interface ActeFrequent {
  libelle: string;
  total: number;
}

export interface VueGeneraleStats {
  derniere_mise_a_jour: string;
  kpis: {
    consultations_30j: number;
    rendez_vous_30j: number;
    absents_30j: number;
    taux_absenteisme_30j: number;
  };
  patients_total: number;
  patients_tendance: number;
  consultations_30j: number;
  consultations_tendance: number;
  rendez_vous_30j: number;
  rendez_vous_tendance: number;
  taux_absenteisme_30j: number;
  taux_absenteisme_tendance: number;
  actes_30j: number;
  actes_tendance: number;
  ordonnances_30j: number;
  ordonnances_tendance: number;
  chiffre_affaires_mois: number;
  ca_tendance: number;
  rendez_vois_mois: RendezVousParMois[];
  max_rendez_vois: number;
  patient_categories: CategoriePatient[];
  metriques_detaillees: MetriqueDetaillee[];
  series: {
    consultations_par_jour: { jour: string; total: number }[];
    consultations_par_praticien: ConsultationParPraticien[];
    pathologies_tendance: PathologieTendance[];
    actes_frequents: ActeFrequent[];
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
