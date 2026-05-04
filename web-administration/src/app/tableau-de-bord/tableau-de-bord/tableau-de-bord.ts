import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration, Chart } from 'chart.js';
import { Router } from '@angular/router';

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
export class TableauDeBord implements OnInit {
  private readonly statsService = inject(StatistiquesService);
  readonly dashboardService = inject(DashboardService);
  private readonly router = inject(Router);
  private readonly auth = inject(Authentification);
  private readonly cdr = inject(ChangeDetectorRef);
  
  stats: VueGeneraleStats | null = null;
  dashboardStats: DashboardStats | null = null;
  chargement = false;
  erreurBackend = false;
  messageErreur = '';
  
  // Propriétés calculées pour éviter l'erreur NG0100
  get tendanceFormatted(): string {
    const tendance = this.dashboardStats?.consultations?.tendance ?? 0;
    return tendance.toFixed(1);
  }

  get rendezVousTendanceFormatted(): string {
    const tendance = this.dashboardStats?.rendezVous?.tendance ?? 0;
    return tendance.toFixed(1);
  }

  get appelsTendanceFormatted(): string {
    const tendance = this.dashboardStats?.appels?.tendance ?? 0;
    return tendance.toFixed(1);
  }

  get tauxAbsenteeismeTendanceFormatted(): string {
    const tendance = this.dashboardStats?.tauxAbsenteeisme?.tendance ?? 0;
    return tendance.toFixed(1);
  }

  get tauxAbsenteeismeGlobalFormatted(): string {
    const taux = this.dashboardStats?.tauxAbsenteeisme?.global ?? 0;
    return taux.toFixed(1);
  }
  
  // Propriétés pour l'actualisation en temps réel
  private refreshInterval: any = null;
  private readonly REFRESH_INTERVAL_MS = 30000; // 30 secondes
  
  // Propriétés pour les graphiques
  consultationsChart: Chart | null = null;
  pathologiesChart: Chart | null = null;
  
  // Options des graphiques
  public chartOptions: ChartConfiguration['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'top',
        labels: {
          font: {
            size: 12
          }
        }
      },
      tooltip: {
        mode: 'index',
        intersect: false,
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        titleFont: {
          size: 14
        },
        bodyFont: {
          size: 12
        }
      }
    },
    scales: {
      x: {
        grid: {
          display: false
        }
      },
      y: {
        beginAtZero: true,
        grid: {
          color: 'rgba(0, 0, 0, 0.05)'
        }
      }
    }
  };

  consultationsChartData: ChartConfiguration<'line'>['data'] = {
    labels: [],
    datasets: [{ data: [], label: 'Consultations', borderColor: '#1E4DB7', tension: 0.3 }],
  };

  pathologiesChartData: ChartConfiguration<'bar'>['data'] = {
    labels: [],
    datasets: [{ data: [], label: 'Pathologies', backgroundColor: '#1A2E6B' }],
  };

  ngOnInit(): void {
    this.charger();
    this.demarrerActualisationTempsReel();
  }

  ngOnDestroy(): void {
    this.arreterActualisationTempsReel();
  }

  // Démarrer l'actualisation en temps réel
  private demarrerActualisationTempsReel(): void {
    this.refreshInterval = setInterval(() => {
      this.chargerSilencieux();
    }, this.REFRESH_INTERVAL_MS);
  }

  // Arrêter l'actualisation en temps réel
  private arreterActualisationTempsReel(): void {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
      this.refreshInterval = null;
    }
  }

  // Chargement silencieux pour l'actualisation en temps réel
  private chargerSilencieux(): void {
    if (!this.auth.estConnecte()) return;

    this.dashboardService.getDashboardStats().subscribe({
      next: (data: DashboardStats) => {
        setTimeout(() => {
          this.dashboardStats = data;
          this.erreurBackend = false;
          this.cdr.detectChanges();
        });
      },
      error: (error: any) => {
        console.error('Erreur actualisation dashboard:', error);
      }
    });
  }

  charger(): void {
    // Vérifier si l'utilisateur est authentifié
    if (!this.auth.estConnecte()) {
      this.router.navigate(['/connexion']);
      return;
    }

    this.chargement = true;
    
    // Charger les statistiques du dashboard
    this.dashboardService.getDashboardStats().subscribe({
      next: (data: DashboardStats) => {
        // Utiliser setTimeout pour éviter NG0100
        setTimeout(() => {
          this.dashboardStats = data;
          this.erreurBackend = false;
        });
      },
      error: (error: any) => {
        console.error('Erreur dashboard stats:', error);
        setTimeout(() => {
          this.erreurBackend = true;
          this.messageErreur = error.message || 'Le serveur n\'est pas accessible. Veuillez contacter l\'administrateur système.';
          this.chargement = false;
        });
      }
    });

    this.statsService.vueGenerale().subscribe({
      next: (data) => {
        this.stats = data;
        this.consultationsChartData = {
          labels: data.series.consultations_par_jour.map((x) => x.jour),
          datasets: [{ data: data.series.consultations_par_jour.map((x) => x.total), label: 'Consultations', borderColor: '#1E4DB7', tension: 0.3 }],
        };
        this.pathologiesChartData = {
          labels: data.series.pathologies_tendance.map((x) => x.diagnostic),
          datasets: [{ data: data.series.pathologies_tendance.map((x) => x.total), label: 'Pathologies', backgroundColor: '#1A2E6B' }],
        };
        this.chargement = false;
        
        // Initialiser les graphiques après le chargement des données
        this.initialiserGraphiques();
      },
      error: (error) => {
        console.error('Erreur vue générale:', error);
        this.chargement = false;
      },
    });
  }

  // Méthodes de navigation vers les différentes pages
  naviguerVersConsultations(): void {
    console.log('Navigation vers consultations demandée');
    this.router.navigate(['/consultations']).then(
      success => console.log('Navigation réussie:', success),
      error => console.error('Erreur de navigation:', error)
    );
  }

  naviguerVersRendezVous(): void {
    console.log('Navigation vers rendez-vous');
    this.router.navigate(['/rendez-vous']);
  }

  naviguerVersAppels(): void {
    console.log('Navigation vers appels');
    this.router.navigate(['/appels']);
  }

  naviguerVersTauxAbsenteisme(): void {
    console.log('Navigation vers taux absentéisme');
    this.router.navigate(['/taux-absenteisme']);
  }

  showHelp(): void {
    alert(`Instructions pour résoudre le problème de connexion au serveur :

1. Vérifier que le serveur Django est démarré :
   cd c:\\warms\\backend
   python manage.py runserver

2. Vérifier que PostgreSQL est en cours d'exécution

3. Vérifier la configuration dans .env :
   - DB_HOST=localhost
   - DB_PORT=5432
   - DB_NAME=warms
   - DB_USER=postgres
   - DB_PASSWORD=votre_mot_de_passe

4. Tester l'accès à l'API :
   Ouvrir http://127.0.0.1:8000/api/v1/personnel/ping/ dans le navigateur

5. Si le problème persiste, contacter l'administrateur système.`);
  }

  // Exporter un graphique en PNG
  exporterGraphique(chartType: 'consultations' | 'pathologies'): void {
    const chart = chartType === 'consultations' ? this.consultationsChart : this.pathologiesChart;
    if (!chart) {
      alert('Graphique non disponible pour l\'exportation');
      return;
    }

    const url = chart.toBase64Image();
    const link = document.createElement('a');
    link.download = `graphique-${chartType}-${new Date().toISOString().split('T')[0]}.png`;
    link.href = url;
    link.click();
  }

  // Mettre un graphique en plein écran
  pleinEcran(chartType: 'consultations' | 'pathologies'): void {
    const chartId = chartType === 'consultations' ? 'consultations-chart' : 'pathologies-chart';
    const chartElement = document.getElementById(chartId);
    
    if (!chartElement) {
      alert('Graphique non trouvé pour le mode plein écran');
      return;
    }

    if (chartElement.requestFullscreen) {
      chartElement.requestFullscreen();
    } else if ((chartElement as any).webkitRequestFullscreen) {
      (chartElement as any).webkitRequestFullscreen();
    } else if ((chartElement as any).msRequestFullscreen) {
      (chartElement as any).msRequestFullscreen();
    }
  }

  // Actions rapides
  nouvelleConsultation(): void {
    this.router.navigate(['/consultations/nouveau']);
  }

  prendreRendezVous(): void {
    this.router.navigate(['/rendez-vous/nouveau']);
  }

  contacterPatient(): void {
    this.router.navigate(['/patients/contacter']);
  }

  // Initialiser les graphiques après le chargement des données
  private initialiserGraphiques(): void {
    setTimeout(() => {
      // Références aux éléments canvas
      const consultationsCanvas = document.getElementById('consultations-chart') as HTMLCanvasElement;
      const pathologiesCanvas = document.getElementById('pathologies-chart') as HTMLCanvasElement;

      if (consultationsCanvas && this.consultationsChartData?.labels && this.consultationsChartData.labels.length > 0) {
        this.consultationsChart = new Chart(consultationsCanvas, {
          type: 'line',
          data: this.consultationsChartData,
          options: this.chartOptions
        });
      }

      if (pathologiesCanvas && this.pathologiesChartData?.labels && this.pathologiesChartData.labels.length > 0) {
        this.pathologiesChart = new Chart(pathologiesCanvas, {
          type: 'bar',
          data: this.pathologiesChartData,
          options: this.chartOptions
        });
      }
    }, 100);
  }
}
