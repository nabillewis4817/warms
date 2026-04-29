import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration } from 'chart.js';
import { Router } from '@angular/router';

import { StatistiquesService, VueGeneraleStats } from '../../noyau/services/statistiques';
import { Authentification } from '../../noyau/services/authentification';
import { UserProfileComponent } from '../user-profile/user-profile.component';

@Component({
  selector: 'app-tableau-de-bord',
  imports: [CommonModule, BaseChartDirective, UserProfileComponent],
  templateUrl: './tableau-de-bord.html',
  styleUrls: ['./tableau-de-bord.scss'],
})
export class TableauDeBord implements OnInit {
  private readonly statsService = inject(StatistiquesService);
  private readonly router = inject(Router);
  private readonly auth = inject(Authentification);
  stats: VueGeneraleStats | null = null;
  chargement = false;

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
  }

  charger(): void {
    // Vérifier si l'utilisateur est authentifié
    if (!this.auth.estConnecte()) {
      this.router.navigate(['/connexion']);
      return;
    }

    this.chargement = true;
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
      },
      error: (error) => {
        console.error('Erreur lors du chargement des statistiques:', error);
        // En cas d'erreur 401, l'intercepteur JWT gérera la redirection
        this.chargement = false;
      },
      complete: () => {
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
    console.log('🔍 DEBUG - Clic sur card Rendez-vous détecté');
    console.log('🔍 DEBUG - Tentative de navigation vers /rendez-vous');
    
    try {
      this.router.navigate(['/rendez-vous']).then(
        success => {
          console.log('✅ Navigation rendez-vous réussie:', success);
        },
        error => {
          console.error('❌ Erreur navigation rendez-vous:', error);
        }
      );
    } catch (error) {
      console.error('❌ Exception dans navigation rendez-vous:', error);
    }
  }

  naviguerVersAppels(): void {
    console.log('🔍 DEBUG - Clic sur card Appels détecté');
    console.log('🔍 DEBUG - Tentative de navigation vers /appels');
    
    try {
      this.router.navigate(['/appels']).then(
        success => {
          console.log('✅ Navigation appels réussie:', success);
        },
        error => {
          console.error('❌ Erreur navigation appels:', error);
        }
      );
    } catch (error) {
      console.error('❌ Exception dans navigation appels:', error);
    }
  }

  naviguerVersTauxAbsenteisme(): void {
    console.log('🔍 DEBUG - Clic sur card Taux Absentéisme détecté');
    console.log('🔍 DEBUG - Tentative de navigation vers /taux-absenteisme');
    
    try {
      this.router.navigate(['/taux-absenteisme']).then(
        success => {
          console.log('✅ Navigation taux-absenteisme réussie:', success);
        },
        error => {
          console.error('❌ Erreur navigation taux-absenteisme:', error);
        }
      );
    } catch (error) {
      console.error('❌ Exception dans navigation taux-absenteisme:', error);
    }
  }

  }

// #EbaJioloLewis
