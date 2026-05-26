import { CommonModule } from '@angular/common';
import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration, Chart } from 'chart.js';
import { Router } from '@angular/router';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';

import { StatistiquesService, VueGeneraleStats } from '../../noyau/services/statistiques';
import { Authentification } from '../../noyau/services/authentification';
import { DashboardService, DashboardStats } from '../../noyau/services/dashboard';
import { UserProfileComponent } from '../user-profile/user-profile.component';

@Component({
  selector: 'app-tableau-de-bord',
  imports: [CommonModule, BaseChartDirective, UserProfileComponent],
  templateUrl: './tableau-de-bord.html',
  styleUrls: ['./tableau-de-bord.scss'],
})
export class TableauDeBord implements OnInit, OnDestroy {
  private readonly statsService = inject(StatistiquesService);
  readonly dashboardService = inject(DashboardService);
  private readonly router = inject(Router);
  private readonly auth = inject(Authentification);
  private readonly cdr = inject(ChangeDetectorRef);

  stats: VueGeneraleStats | null = null;
  dashboardStats: DashboardStats | null = null;
  chargement = false;
  erreurBackend = false;
  erreurGraphiques = false;
  messageErreur = '';

  private refreshInterval: ReturnType<typeof setInterval> | null = null;
  private readonly REFRESH_INTERVAL_MS = 30000;

  get tendanceFormatted(): string {
    return (this.dashboardStats?.consultations?.tendance ?? 0).toFixed(1);
  }

  get rendezVousTendanceFormatted(): string {
    return (this.dashboardStats?.rendezVous?.tendance ?? 0).toFixed(1);
  }

  get appelsTendanceFormatted(): string {
    return (this.dashboardStats?.appels?.tendance ?? 0).toFixed(1);
  }

  get tauxAbsenteeismeTendanceFormatted(): string {
    return (this.dashboardStats?.tauxAbsenteeisme?.tendance ?? 0).toFixed(1);
  }

  get tauxAbsenteeismeGlobalFormatted(): string {
    return (this.dashboardStats?.tauxAbsenteeisme?.global ?? 0).toFixed(1);
  }

  public chartOptions: ChartConfiguration['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { position: 'top', labels: { font: { size: 12 } } },
      tooltip: {
        mode: 'index',
        intersect: false,
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        titleFont: { size: 14 },
        bodyFont: { size: 12 },
      },
    },
    scales: {
      x: { grid: { display: false } },
      y: { beginAtZero: true, grid: { color: 'rgba(0, 0, 0, 0.05)' } },
    },
  };

  consultationsChartData: ChartConfiguration<'line'>['data'] = {
    labels: [],
    datasets: [{ data: [], label: 'Consultations', borderColor: '#1E4DB7', tension: 0.3 }],
  };

  pathologiesChartData: ChartConfiguration<'bar'>['data'] = {
    labels: [],
    datasets: [{ data: [], label: 'Pathologies', backgroundColor: '#1A2E6B' }],
  };

  consultationsChart: Chart | null = null;
  pathologiesChart: Chart | null = null;

  ngOnInit(): void {
    this.charger();
    this.refreshInterval = setInterval(() => this.chargerSilencieux(), this.REFRESH_INTERVAL_MS);
  }

  ngOnDestroy(): void {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
      this.refreshInterval = null;
    }
    this.consultationsChart?.destroy();
    this.pathologiesChart?.destroy();
  }

  private chargerSilencieux(): void {
    if (!this.auth.estConnecte()) return;
    this.dashboardService.getDashboardStats().subscribe({
      next: (data) => {
        this.dashboardStats = data;
        this.cdr.detectChanges();
      },
    });
  }

  charger(): void {
    if (!this.auth.estConnecte()) {
      this.router.navigate(['/connexion']);
      return;
    }

    this.chargement = true;
    this.erreurBackend = false;
    this.erreurGraphiques = false;
    this.messageErreur = '';

    forkJoin({
      dashboard: this.dashboardService.getDashboardStats().pipe(
        catchError((error) => {
          console.error('Erreur dashboard stats:', error);
          return of(null);
        })
      ),
      vueGenerale: this.statsService.vueGenerale().pipe(
        catchError((error) => {
          console.error('Erreur vue générale:', error);
          return of(null);
        })
      ),
    }).subscribe(({ dashboard, vueGenerale }) => {
      if (dashboard) {
        this.dashboardStats = dashboard;
      } else {
        this.erreurBackend = true;
        this.messageErreur =
          "Impossible de charger les indicateurs du tableau de bord. Vérifiez que le serveur est démarré et que vous êtes connecté.";
      }

      if (vueGenerale?.series) {
        this.stats = vueGenerale;
        this.appliquerDonneesGraphiques(vueGenerale);
      } else {
        this.erreurGraphiques = true;
        if (!dashboard) {
          this.messageErreur =
            "Impossible de charger les données. Démarrez le backend (python manage.py runserver) puis reconnectez-vous.";
        }
      }

      this.chargement = false;
      this.cdr.detectChanges();

      if (vueGenerale?.series) {
        this.initialiserGraphiques();
      }
    });
  }

  private appliquerDonneesGraphiques(data: VueGeneraleStats): void {
    const parJour = data.series?.consultations_par_jour ?? [];
    const pathologies = data.series?.pathologies_tendance ?? [];

    this.consultationsChartData = {
      labels: parJour.map((x) => this.formaterJour(String(x.jour))),
      datasets: [
        {
          data: parJour.map((x) => x.total),
          label: 'Consultations',
          borderColor: '#1E4DB7',
          tension: 0.3,
        },
      ],
    };

    this.pathologiesChartData = {
      labels: pathologies.map((x) => x.diagnostic || '—'),
      datasets: [
        {
          data: pathologies.map((x) => x.total),
          label: 'Pathologies',
          backgroundColor: '#1A2E6B',
        },
      ],
    };
  }

  private formaterJour(jour: string): string {
    if (!jour) return '—';
    const d = new Date(jour);
    if (Number.isNaN(d.getTime())) return jour;
    return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });
  }

  naviguerVersConsultations(): void {
    this.router.navigate(['/consultations']);
  }

  naviguerVersRendezVous(): void {
    this.router.navigate(['/rendez-vous']);
  }

  naviguerVersAppels(): void {
    this.router.navigate(['/appels']);
  }

  naviguerVersTauxAbsenteisme(): void {
    this.router.navigate(['/taux-absenteisme']);
  }

  showHelp(): void {
    alert(`Pour résoudre les problèmes de connexion :

1. Démarrer le backend :
   cd c:\\warms\\backend
   python manage.py runserver

2. Se connecter sur /connexion avec un compte valide

3. Tester : http://127.0.0.1:8000/api/v1/personnel/ping/

4. Si les cartes KPI sont vides mais sans erreur, créez des consultations / RDV / appels dans les onglets dédiés.`);
  }

  exporterGraphique(chartType: 'consultations' | 'pathologies'): void {
    const chart = chartType === 'consultations' ? this.consultationsChart : this.pathologiesChart;
    if (!chart) {
      alert("Graphique non disponible pour l'exportation");
      return;
    }
    const link = document.createElement('a');
    link.download = `graphique-${chartType}-${new Date().toISOString().split('T')[0]}.png`;
    link.href = chart.toBase64Image();
    link.click();
  }

  pleinEcran(chartType: 'consultations' | 'pathologies'): void {
    const chartId = chartType === 'consultations' ? 'consultations-chart' : 'pathologies-chart';
    const chartElement = document.getElementById(chartId);
    if (!chartElement?.requestFullscreen) return;
    chartElement.requestFullscreen();
  }

  nouvelleConsultation(): void {
    this.router.navigate(['/consultations']);
  }

  prendreRendezVous(): void {
    this.router.navigate(['/rendez-vous']);
  }

  contacterPatient(): void {
    this.router.navigate(['/patients']);
  }

  private initialiserGraphiques(): void {
    setTimeout(() => {
      this.consultationsChart?.destroy();
      this.pathologiesChart?.destroy();

      const consultationsCanvas = document.getElementById('consultations-chart') as HTMLCanvasElement;
      const pathologiesCanvas = document.getElementById('pathologies-chart') as HTMLCanvasElement;

      if (consultationsCanvas && this.consultationsChartData.labels?.length) {
        this.consultationsChart = new Chart(consultationsCanvas, {
          type: 'line',
          data: this.consultationsChartData,
          options: this.chartOptions,
        });
      }

      if (pathologiesCanvas && this.pathologiesChartData.labels?.length) {
        this.pathologiesChart = new Chart(pathologiesCanvas, {
          type: 'bar',
          data: this.pathologiesChartData,
          options: this.chartOptions,
        });
      }
    }, 100);
  }
}
