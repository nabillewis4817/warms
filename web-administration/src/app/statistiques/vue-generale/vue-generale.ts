import { CommonModule } from '@angular/common';
import { Component, OnInit, OnDestroy } from '@angular/core';
import { interval, Subscription } from 'rxjs';

import { StatistiquesService } from '../../noyau/services/statistiques';

export interface StatsCabinet {
  derniere_mise_a_jour?: string;
  patients_total?: number;
  patients_tendance?: number;
  rendez_vous_30j?: number;
  rendez_vous_tendance?: number;
  ordonnances_30j?: number;
  ordonnances_tendance?: number;
  chiffre_affaires_mois?: number;
  ca_tendance?: number;
  max_rendez_vois?: number;
  rendez_vois_mois?: { mois: string; nombre: number }[];
  patient_categories?: { nom: string; nombre: number; couleur: string }[];
  metriques_detaillees?: { nom: string; valeur: string | number; periode: string; tendance: number }[];
}

@Component({
  selector: 'app-vue-generale',
  imports: [CommonModule],
  templateUrl: './vue-generale.html',
  styleUrl: './vue-generale.scss',
})
export class VueGenerale implements OnInit, OnDestroy {
  stats: StatsCabinet | null = null;
  loading = true;
  error: string | null = null;
  private refreshSubscription: Subscription | null = null;

  constructor(private statsService: StatistiquesService) {}

  ngOnInit(): void {
    this.chargerStats();
    this.refreshSubscription = interval(30000).subscribe(() => this.chargerStats());
  }

  ngOnDestroy(): void {
    this.refreshSubscription?.unsubscribe();
  }

  chargerStats(): void {
    this.loading = true;
    this.error = null;

    this.statsService.vueGenerale().subscribe({
      next: (data) => {
        const kpis = (data as { kpis?: Record<string, number> }).kpis ?? {};
        this.stats = {
          derniere_mise_a_jour: (data as StatsCabinet).derniere_mise_a_jour,
          patients_total: (data as StatsCabinet).patients_total ?? 0,
          patients_tendance: (data as StatsCabinet).patients_tendance ?? 0,
          rendez_vous_30j: (data as StatsCabinet).rendez_vous_30j ?? kpis['rendez_vous_30j'],
          rendez_vous_tendance: (data as StatsCabinet).rendez_vous_tendance ?? 0,
          ordonnances_30j: (data as StatsCabinet).ordonnances_30j ?? 0,
          ordonnances_tendance: (data as StatsCabinet).ordonnances_tendance ?? 0,
          chiffre_affaires_mois: (data as StatsCabinet).chiffre_affaires_mois ?? 0,
          ca_tendance: (data as StatsCabinet).ca_tendance ?? 0,
          max_rendez_vois: (data as StatsCabinet).max_rendez_vois ?? 1,
          rendez_vois_mois: (data as StatsCabinet).rendez_vois_mois ?? [],
          patient_categories: (data as StatsCabinet).patient_categories ?? [],
          metriques_detaillees: (data as StatsCabinet).metriques_detaillees ?? [],
        };
        this.loading = false;
      },
      error: (err) => {
        console.error('Erreur lors du chargement des statistiques:', err);
        this.error = 'Impossible de charger les statistiques depuis le serveur.';
        this.loading = false;
      },
    });
  }

  getPourcentage(value: number, total: number): number {
    return total > 0 ? Math.round((value / total) * 100) : 0;
  }

  getTendance(value: number): string {
    if (value > 0) return 'positive';
    if (value < 0) return 'negative';
    return 'stable';
  }

  rafraichir(): void {
    this.chargerStats();
  }
}
