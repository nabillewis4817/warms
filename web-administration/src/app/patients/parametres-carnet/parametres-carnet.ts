import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';

import { Patients } from '../../noyau/services/patients';

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
