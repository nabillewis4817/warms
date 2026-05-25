import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';

import { TauxAbsenteismeService, TauxAbsenteisme, CalculerTauxPayload } from '../../noyau/services/taux-absenteisme';

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

  filterForm = this.fb.group({
    periode: ['mois'],
    date_debut: [''],
    date_fin: [''],
  });

  stats = {
    totalTaux: 0,
    tauxMoyen: 0,
    tendance: 'stable',
    periodeAnalyse: 'Ce mois',
  };

  ngOnInit(): void {
    this.initialiserDates();
    this.loadTauxAbsenteisme();
  }

  private initialiserDates(): void {
    const fin = new Date();
    const debut = new Date();
    debut.setDate(1);
    this.filterForm.patchValue({
      date_debut: debut.toISOString().split('T')[0],
      date_fin: fin.toISOString().split('T')[0],
      periode: 'mois',
    });
  }

  loadTauxAbsenteisme(): void {
    this.loading = true;
    this.tauxAbsenteismeService.historique(this.filterForm.value.periode || 'mois').subscribe({
      next: (data) => {
        this.tauxList = data;
        this.calculerStatsLocales();
        this.loading = false;
      },
      error: () => {
        this.tauxList = [];
        this.loading = false;
        this.message = 'Impossible de charger l\'historique des taux.';
      },
    });
  }

  private calculerStatsLocales(): void {
    if (!this.tauxList.length) {
      this.stats = { totalTaux: 0, tauxMoyen: 0, tendance: 'stable', periodeAnalyse: '—' };
      return;
    }
    const moyenne = this.tauxList.reduce((s, t) => s + t.taux_absenteisme, 0) / this.tauxList.length;
    const dernier = this.tauxList[0];
    const avant = this.tauxList[1];
    let tendance = 'stable';
    if (avant && dernier.taux_absenteisme < avant.taux_absenteisme) tendance = 'en_baisse';
    if (avant && dernier.taux_absenteisme > avant.taux_absenteisme) tendance = 'en_hausse';
    this.stats = {
      totalTaux: this.tauxList.length,
      tauxMoyen: Math.round(moyenne * 10) / 10,
      tendance,
      periodeAnalyse: `${dernier.periode_debut} → ${dernier.periode_fin}`,
    };
  }

  calculerPeriode(): void {
    const v = this.filterForm.getRawValue();
    if (!v.date_debut || !v.date_fin) {
      this.message = 'Indiquez une date de début et de fin.';
      return;
    }
    const payload: CalculerTauxPayload = {
      periode_debut: v.date_debut,
      periode_fin: v.date_fin,
      type_periode: v.periode || 'mois',
    };
    this.loading = true;
    this.tauxAbsenteismeService.calculer(payload).subscribe({
      next: () => {
        this.message = 'Taux calculé et enregistré.';
        this.loadTauxAbsenteisme();
      },
      error: (err) => {
        this.loading = false;
        this.message = err?.error?.error || 'Erreur lors du calcul du taux.';
      },
    });
  }

  appliquerFiltres(): void {
    this.loadTauxAbsenteisme();
  }

  reinitialiserFiltres(): void {
    this.initialiserDates();
    this.loadTauxAbsenteisme();
  }

  exporter(format: string): void {
    this.message = `Export ${format} — utilisez l'onglet Appels pour le détail.`;
  }

  getTauxColor(taux: number): string {
    if (taux < 5) return '#22c55e';
    if (taux < 10) return '#f59e0b';
    return '#dc2626';
  }

  getTendanceIcon(tendance: string): string {
    switch (tendance) {
      case 'en_hausse': return 'bi-arrow-up';
      case 'en_baisse': return 'bi-arrow-down';
      default: return 'bi-dash';
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
