import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { CommonModule } from '@angular/common';
import { Patients, Patient } from '../../noyau/services/patients';

@Component({
  selector: 'app-dossier-patient',
  imports: [CommonModule],
  templateUrl: './dossier-patient.html',
  styleUrl: './carnet-patient.scss',
})
export class DossierPatient implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly patientsService = inject(Patients);
  
  patient: Patient | null = null;
  loading = true;
  erreur = '';
  currentPage = 0;
  isAnimating = false;
  
  ngOnInit(): void {
    this.route.params.subscribe(params => {
      const patientId = params['id'];
      if (patientId) {
        this.chargerPatient(patientId);
      } else {
        this.erreur = 'Aucun identifiant de patient spécifié';
        this.loading = false;
      }
    });
  }
  
  chargerPatient(id: string): void {
    this.loading = true;
    this.patientsService.detail(Number(id)).subscribe({
      next: (patient) => {
        this.patient = patient;
        this.loading = false;
      },
      error: (err) => {
        console.error('Erreur lors du chargement du patient:', err);
        this.erreur = 'Impossible de charger les informations du patient';
        this.loading = false;
      }
    });
  }
  
  ouvrirCarnet(): void {
    if (!this.isAnimating) {
      this.isAnimating = true;
      this.currentPage = 1;
      setTimeout(() => {
        this.isAnimating = false;
      }, 600);
    }
  }
  
  pageSuivante(): void {
    if (this.currentPage < 6 && !this.isAnimating) {
      this.isAnimating = true;
      this.currentPage++;
      setTimeout(() => {
        this.isAnimating = false;
      }, 600);
    }
  }
  
  pagePrecedente(): void {
    if (this.currentPage > 1 && !this.isAnimating) {
      this.isAnimating = true;
      this.currentPage--;
      setTimeout(() => {
        this.isAnimating = false;
      }, 600);
    }
  }
  
  retryChargement(): void {
    this.route.params.subscribe(params => {
      const patientId = params['id'];
      if (patientId) {
        this.chargerPatient(patientId);
      }
    });
  }
  
  getPageTitre(): string {
    switch (this.currentPage) {
      case 1:
        return 'Informations Personnelles';
      case 2:
        return 'Symptômes Actuels';
      case 3:
        return 'Informations Médicales';
      case 4:
        return 'Consultations Précédentes';
      case 5:
        return 'Historique';
      case 6:
        return 'Dernière Consultation';
      default:
        return 'Carnet Patient';
    }
  }
}
