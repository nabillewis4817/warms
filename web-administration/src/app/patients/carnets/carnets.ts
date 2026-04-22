import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';

import { Patient, Patients } from '../../noyau/services/patients';

@Component({
  selector: 'app-carnets',
  imports: [CommonModule],
  templateUrl: './carnets.html',
  styleUrl: './carnets.scss',
})
export class Carnets implements OnInit {
  private readonly patientsService = inject(Patients);
  patients: Patient[] = [];

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.patientsService.lister().subscribe({
      next: (items) => (this.patients = items.filter((p) => !!p.numero_dossier)),
    });
  }

  initiale(p: Patient): string {
    return (p.nom?.[0] || p.prenom?.[0] || '?').toUpperCase();
  }
}

// #EbaJioloLewis
