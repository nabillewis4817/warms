import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';

import { TauxAbsenteismeService } from '../../noyau/services/taux-absenteisme';
import { TauxAbsenteisme } from '../../noyau/services/taux-absenteisme';

@Component({
  selector: 'app-taux-absenteisme',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './taux-absenteisme.html',
  styleUrl: './taux-absenteisme.scss',
})
export class TauxAbsenteismeComponent implements OnInit {
  private readonly tauxAbsenteismeService = inject(TauxAbsenteismeService);
  private readonly fb = inject(FormBuilder);
  private readonly router = inject(Router);

  tauxList: TauxAbsenteisme[] = [];
  loading = false;
  message = '';

  // Filtres
  filterForm = this.fb.group({
    periode: ['mois'],
    date_debut: [''],
    date_fin: [''],
    service: ['']
  });

  // Statistiques
  stats = {
    totalTaux: 0,
    tauxMoyen: 0,
    tendance: 'stable',
    periodeAnalyse: 'Ce mois'
  };

  ngOnInit(): void {
    this.loadTauxAbsenteisme();
    this.loadStats();
  }

  loadTauxAbsenteisme(): void {
    this.loading = true;
    this.tauxAbsenteismeService.lister().subscribe({
      next: (data: TauxAbsenteisme[]) => {
        this.tauxList = data;
        this.loading = false;
      },
      error: (err: any) => {
        console.error('Erreur lors du chargement des taux d\'absentéisme:', err);
        this.message = 'Impossible de charger les taux d\'absentéisme';
        this.loading = false;
      }
    });
  }

  loadStats(): void {
    // Simuler des statistiques - à remplacer par l'appel API réel
    this.stats = {
      totalTaux: 12.5,
      tauxMoyen: 10.2,
      tendance: 'en_baisse',
      periodeAnalyse: 'Ce mois'
    };
  }

  appliquerFiltres(): void {
    const filters = this.filterForm.value;
    console.log('Filtres appliqués:', filters);
    // Appliquer les filtres via le service
    this.loadTauxAbsenteisme();
  }

  reinitialiserFiltres(): void {
    this.filterForm.reset({
      periode: 'mois',
      date_debut: '',
      date_fin: '',
      service: ''
    });
    this.loadTauxAbsenteisme();
  }

  exporter(format: string): void {
    console.log('Exportation au format:', format);
    this.message = `Exportation ${format} en cours...`;
    // Implémenter l'exportation
  }

  getTauxColor(taux: number): string {
    if (taux < 5) return '#22c55e'; // Vert - bon
    if (taux < 10) return '#f59e0b'; // Orange - attention
    return '#dc2626'; // Rouge - critique
  }

  getTendanceIcon(tendance: string): string {
    switch (tendance) {
      case 'en_hausse': return 'bi-arrow-up-circle-fill';
      case 'en_baisse': return 'bi-arrow-down-circle-fill';
      default: return 'bi-dash-circle-fill';
    }
  }

  getTendanceColor(tendance: string): string {
    switch (tendance) {
      case 'en_hausse': return '#dc2626';
      case 'en_baisse': return '#22c55e';
      default: return '#6b7280';
    }
  }
}
