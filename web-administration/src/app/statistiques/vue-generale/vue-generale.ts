import { CommonModule } from '@angular/common';
import { Component, OnInit, OnDestroy } from '@angular/core';
import { interval, Subscription } from 'rxjs';

import { StatistiquesService } from '../../noyau/services/statistiques';

@Component({
  selector: 'app-vue-generale',
  imports: [CommonModule],
  templateUrl: './vue-generale.html',
  styleUrl: './vue-generale.scss',
})
export class VueGenerale implements OnInit, OnDestroy {
  stats: Record<string, unknown> = {};
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
        this.stats = { ...data, ...(data['kpis'] as object) };
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
