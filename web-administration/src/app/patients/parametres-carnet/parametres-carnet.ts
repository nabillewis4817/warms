import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';

import { Patients, Patient } from '../../noyau/services/patients';

@Component({
  selector: 'app-parametres-carnet',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './parametres-carnet.html',
  styleUrl: './parametres-carnet.scss',
})
export class ParametresCarnet implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly fb = inject(FormBuilder);
  private readonly patientsService = inject(Patients);
  patientId = 0;
  etape = 1;
  message = '';
  loading = true;
  patient: Patient | null = null;

  form = this.fb.group({
    sexe: ['M', Validators.required],
    age: [null as number | null],
    taille_cm: [null as number | null],
    poids_kg: [null as number | null],
    symptomes: [''],
    consultations_precedentes: [''],
  });

  ngOnInit(): void {
    this.patientId = Number(this.route.snapshot.paramMap.get('id'));
    if (this.patientId) {
      this.chargerPatient();
    } else {
      this.loading = false;
      this.message = 'Aucun identifiant de patient spécifié';
    }
  }

  chargerPatient(): void {
    this.loading = true;
    this.patientsService.detail(this.patientId).subscribe({
      next: (patient) => {
        this.patient = patient;
        this.remplirFormulaire(patient);
        this.loading = false;
      },
      error: (err) => {
        console.error('Erreur lors du chargement du patient:', err);
        this.message = 'Impossible de charger les informations du patient';
        this.loading = false;
      }
    });
  }

  remplirFormulaire(patient: Patient): void {
    this.form.patchValue({
      sexe: patient.sexe || 'M',
      age: patient.date_naissance ? this.calculerAge(patient.date_naissance) : null,
      taille_cm: patient.taille_cm ? Number(patient.taille_cm) : null,
      poids_kg: patient.poids_kg ? Number(patient.poids_kg) : null,
      symptomes: patient.symptomes || '',
      consultations_precedentes: patient.consultations_precedentes || '',
    });
  }

  calculerAge(dateNaissance: string): number {
    const naissance = new Date(dateNaissance);
    const aujourdHui = new Date();
    let age = aujourdHui.getFullYear() - naissance.getFullYear();
    const moisDiff = aujourdHui.getMonth() - naissance.getMonth();
    
    if (moisDiff < 0 || (moisDiff === 0 && aujourdHui.getDate() < naissance.getDate())) {
      age--;
    }
    
    return age;
  }

  precedent(): void {
    this.etape = Math.max(1, this.etape - 1);
  }

  suivant(): void {
    this.etape = Math.min(2, this.etape + 1);
  }

  genererCarnet(): void {
    const brut = this.form.getRawValue();
    const payload = Object.fromEntries(
      Object.entries(brut).filter(([, value]) => value !== null && value !== '')
    );
    this.patientsService.modifier(this.patientId, payload).subscribe({
      next: () => {
        this.message = 'Carnet généré avec succès.';
        this.router.navigate(['/carnets']);
      },
      error: () => (this.message = 'Erreur lors de la génération du carnet.'),
    });
  }
}

// #EbaJioloLewis
