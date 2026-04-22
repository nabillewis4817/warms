import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration } from 'chart.js';

import { StatistiquesService, VueGeneraleStats } from '../../noyau/services/statistiques';

@Component({
  selector: 'app-tableau-de-bord',
  imports: [CommonModule, BaseChartDirective],
  templateUrl: './tableau-de-bord.html',
  styleUrl: './tableau-de-bord.scss',
})
export class TableauDeBord implements OnInit {
  private readonly statsService = inject(StatistiquesService);
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
      complete: () => {
        this.chargement = false;
      },
    });
  }
}

// #EbaJioloLewis
