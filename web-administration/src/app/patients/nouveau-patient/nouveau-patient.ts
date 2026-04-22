import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import QRCode from 'qrcode';

import { Patient, Patients } from '../../noyau/services/patients';

@Component({
  selector: 'app-nouveau-patient',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './nouveau-patient.html',
  styleUrl: './nouveau-patient.scss',
})
export class NouveauPatient {
  private readonly fb = inject(FormBuilder);
  private readonly patientsService = inject(Patients);
  private readonly router = inject(Router);
  message = '';
  patientCree: Patient | null = null;
  enCreation = false;
  qrImageData = '';

  form = this.fb.group({
    prenom: ['', Validators.required],
    nom: ['', Validators.required],
    telephone: ['', [Validators.pattern(/^\+237\d{9}$/)]],
    email: [''],
    sexe: ['M', Validators.required],
    username_patient: [''],
    password_patient: [''],
  });

  creer(): void {
    if (this.form.invalid) return;
    this.enCreation = true;
    this.patientsService.creer(this.form.getRawValue() as any).subscribe({
      next: async (patient) => {
        this.patientCree = patient;
        this.message = 'Patient créé avec succès (dossier + QR auto générés).';
        this.qrImageData = patient.qr_token
          ? await QRCode.toDataURL(patient.qr_token, { width: 220, margin: 1 })
          : '';
        const creds = (patient as any).identifiants_patient;
        if (creds?.username && creds?.password) {
          alert(`Identifiants patient à transmettre:\nUsername: ${creds.username}\nPassword: ${creds.password}`);
        }
        this.router.navigate(['/patients', patient.id, 'parametres-carnet']);
      },
      error: (err) =>
        (this.message = err?.error?.detail || 'Échec de création du patient.'),
      complete: () => (this.enCreation = false),
    });
  }

  allerListe(): void {
    this.router.navigate(['/patients']);
  }
}

// #EbaJioloLewis
