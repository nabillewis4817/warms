import { CommonModule } from '@angular/common';
import { Component, OnInit, OnDestroy, ViewChild, inject } from '@angular/core';
import { Router } from '@angular/router';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration } from 'chart.js';
import { interval, Subscription } from 'rxjs';

import { StatistiquesService, VueGeneraleStats } from '../../noyau/services/statistiques';

const COULEURS_PRATICIENS = ['#1e4db7', '#10b981', '#f59e0b', '#ec4899', '#8b5cf6', '#06b6d4'];

@Component({
  selector: 'app-vue-generale',
  imports: [CommonModule, BaseChartDirective],
  templateUrl: './vue-generale.html',
  styleUrl: './vue-generale.scss',
})
export class VueGenerale implements OnInit, OnDestroy {
  stats: VueGeneraleStats | null = null;
  loading = true;
  error: string | null = null;
  private refreshSubscription: Subscription | null = null;

  @ViewChild('evolutionChartDirective') evolutionChartDirective?: BaseChartDirective;
  @ViewChild('repartitionChartDirective') repartitionChartDirective?: BaseChartDirective;
  @ViewChild('actesChartDirective') actesChartDirective?: BaseChartDirective;
  @ViewChild('praticiensChartDirective') praticiensChartDirective?: BaseChartDirective;

  readonly optionsLigne: ChartConfiguration['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: { mode: 'index', intersect: false, backgroundColor: 'rgba(22,50,122,0.92)' },
    },
    scales: {
      x: { grid: { display: false } },
      y: { beginAtZero: true, grid: { color: 'rgba(30,77,183,0.06)' } },
    },
  };

  readonly optionsBarreHorizontale: ChartConfiguration['options'] = {
    indexAxis: 'y',
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: { backgroundColor: 'rgba(22,50,122,0.92)' },
    },
    scales: {
      x: { beginAtZero: true, grid: { color: 'rgba(30,77,183,0.06)' } },
      y: { grid: { display: false } },
    },
  };

  readonly optionsDoughnut: ChartConfiguration<'doughnut'>['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    cutout: '65%',
    plugins: {
      legend: { position: 'bottom', labels: { boxWidth: 12, font: { size: 12 } } },
      tooltip: { backgroundColor: 'rgba(22,50,122,0.92)' },
    },
  };

  evolutionChartData: ChartConfiguration<'line'>['data'] = { labels: [], datasets: [] };
  repartitionChartData: ChartConfiguration<'doughnut'>['data'] = { labels: [], datasets: [] };
  actesChartData: ChartConfiguration<'bar'>['data'] = { labels: [], datasets: [] };
  praticiensChartData: ChartConfiguration<'bar'>['data'] = { labels: [], datasets: [] };

  private readonly router = inject(Router);

  constructor(private statsService: StatistiquesService) {}

  ngOnInit(): void {
    this.chargerStats();
    this.refreshSubscription = interval(30000).subscribe(() => this.chargerStats(true));
  }

  ngOnDestroy(): void {
    this.refreshSubscription?.unsubscribe();
  }

  chargerStats(silencieux = false): void {
    if (!silencieux) {
      this.loading = true;
    }
    this.error = null;

    this.statsService.vueGenerale().subscribe({
      next: (data) => {
        this.stats = data;
        this.construireGraphiques(data);
        this.loading = false;
      },
      error: (err) => {
        console.error('Erreur lors du chargement des statistiques:', err);
        this.error = 'Impossible de charger les statistiques depuis le serveur.';
        this.loading = false;
      },
    });
  }

  private construireGraphiques(data: VueGeneraleStats): void {
    this.evolutionChartData = {
      labels: (data.rendez_vois_mois ?? []).map((m) => m.mois),
      datasets: [
        {
          label: 'Rendez-vous',
          data: (data.rendez_vois_mois ?? []).map((m) => m.nombre),
          borderColor: '#1e4db7',
          backgroundColor: 'rgba(30,77,183,0.1)',
          tension: 0.35,
          fill: true,
          pointBackgroundColor: '#1e4db7',
        },
      ],
    };

    this.repartitionChartData = {
      labels: (data.patient_categories ?? []).map((c) => c.nom),
      datasets: [
        {
          data: (data.patient_categories ?? []).map((c) => c.nombre),
          backgroundColor: (data.patient_categories ?? []).map((c) => c.couleur),
          borderWidth: 0,
        },
      ],
    };

    const actes = (data.series?.actes_frequents ?? []).slice(0, 6);
    this.actesChartData = {
      labels: actes.map((a) => a.libelle || '—'),
      datasets: [
        {
          label: 'Actes',
          data: actes.map((a) => a.total),
          backgroundColor: '#f59e0b',
          borderRadius: 8,
        },
      ],
    };

    const praticiens = (data.series?.consultations_par_praticien ?? []).slice(0, 6);
    this.praticiensChartData = {
      labels: praticiens.map((p) => p.praticien_nom),
      datasets: [
        {
          label: 'Consultations',
          data: praticiens.map((p) => p.total),
          backgroundColor: praticiens.map((_, i) => COULEURS_PRATICIENS[i % COULEURS_PRATICIENS.length]),
          borderRadius: 8,
        },
      ],
    };
  }

  getTendance(value: number): string {
    if (value > 0) return 'positive';
    if (value < 0) return 'negative';
    return 'stable';
  }

  exporterGraphique(type: 'evolution' | 'repartition' | 'actes' | 'praticiens'): void {
    const directive = {
      evolution: this.evolutionChartDirective,
      repartition: this.repartitionChartDirective,
      actes: this.actesChartDirective,
      praticiens: this.praticiensChartDirective,
    }[type];
    const image = directive?.toBase64Image();
    if (!image) return;
    const lien = document.createElement('a');
    lien.download = `statistiques-${type}-${new Date().toISOString().split('T')[0]}.png`;
    lien.href = image;
    lien.click();
  }

  rafraichir(): void {
    this.chargerStats();
  }

  naviguerVersPatients(): void {
    this.router.navigate(['/patients']);
  }

  naviguerVersConsultations(): void {
    this.router.navigate(['/consultations']);
  }

  naviguerVersRendezVous(): void {
    this.router.navigate(['/rendez-vous']);
  }

  naviguerVersTauxAbsenteisme(): void {
    this.router.navigate(['/taux-absenteisme']);
  }

  naviguerVersActes(): void {
    this.router.navigate(['/consultations']);
  }
}
