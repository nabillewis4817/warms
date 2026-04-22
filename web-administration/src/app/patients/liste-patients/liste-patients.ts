import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';

import { Patient, Patients } from '../../noyau/services/patients';

@Component({
  selector: 'app-liste-patients',
  imports: [CommonModule],
  templateUrl: './liste-patients.html',
  styleUrl: './liste-patients.scss',
})
export class ListePatients implements OnInit {
  private readonly patientsService = inject(Patients);
  patients: Patient[] = [];
  chargement = false;
  editionId: number | null = null;

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement = true;
    this.patientsService.lister().subscribe({
      next: (items) => (this.patients = items),
      complete: () => (this.chargement = false),
    });
  }

  basculerEdition(patient: Patient): void {
    this.editionId = this.editionId === patient.id ? null : patient.id;
  }

  archiver(patient: Patient): void {
    this.patientsService.modifier(patient.id, { actif: false } as any).subscribe({
      next: () => this.charger(),
    });
  }

  supprimer(patient: Patient): void {
    this.patientsService.supprimer(patient.id).subscribe({
      next: () => this.charger(),
    });
  }
}

// #EbaJioloLewis
