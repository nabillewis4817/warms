import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import QRCode from 'qrcode';

import { Patient, Patients } from '../../noyau/services/patients';
import { DialogueService } from '../../noyau/services/dialogue.service';

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
  private readonly dialogueService = inject(DialogueService);
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
    username_patient: ['', Validators.required],
    password_patient: ['', [Validators.required, Validators.minLength(6)]],
  });

  creer(): void {
    if (this.form.invalid) {
      // Marquer les champs comme touchés pour afficher les erreurs
      Object.keys(this.form.controls).forEach(key => {
        this.form.get(key)?.markAsTouched();
      });
      return;
    }
    
    this.enCreation = true;
    this.message = '';
    
    const payload = this.form.getRawValue() as any;
    
    // Validation supplémentaire côté client
    if (payload.telephone && !/^\+237\d{9}$/.test(payload.telephone)) {
      this.message = 'Le téléphone doit être au format +237XXXXXXXXX';
      this.enCreation = false;
      return;
    }
    
    if (payload.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payload.email)) {
      this.message = 'Veuillez entrer une adresse email valide';
      this.enCreation = false;
      return;
    }
    
    this.patientsService.creer(payload).subscribe({
      next: async (patient) => {
        this.patientCree = patient;
        this.message = 'Patient créé avec succès (dossier + QR auto générés).';
        this.qrImageData = patient.qr_token
          ? await QRCode.toDataURL(patient.qr_token, { width: 220, margin: 1 })
          : '';
        const creds = (patient as any).identifiants_patient;
        if (creds?.username && creds?.password) {
          this.dialogueService.informer({
            titre: 'Identifiants patient créés',
            message: `Username: ${creds.username}\nPassword: ${creds.password}\n\nTransmettez ces identifiants au patient pour sa connexion mobile.`,
            boutonOk: 'OK'
          }).subscribe();
        }
        
        // Navigation différée pour éviter les conflits avec les intercepteurs
        setTimeout(() => {
          this.router.navigate(['/patients', patient.id, 'parametres-carnet']);
        }, 500);
      },
      error: (err) => {
        console.error('Erreur création patient:', err);
        this.enCreation = false;
        
        // Gestion améliorée des erreurs
        if (err?.status === 400) {
          const detail = err?.error?.detail;
          if (typeof detail === 'string') {
            if (detail.includes('existe déjà')) {
              this.message = 'Un patient avec ces informations existe déjà.';
            } else if (detail.includes('username')) {
              this.message = "Ce nom d'utilisateur patient est déjà utilisé.";
            } else if (detail.includes('obligatoires')) {
              this.message = 'Le nom d\'utilisateur et le mot de passe du patient sont obligatoires.';
            } else {
              this.message = detail;
            }
          } else {
            this.message = 'Erreur de validation: ' + JSON.stringify(detail);
          }
        } else if (err?.status === 401) {
          this.message = 'Erreur d\'authentification. Veuillez vous reconnecter.';
        } else if (err?.status === 403) {
          this.message = 'Vous n\'avez pas les permissions pour créer un patient.';
        } else if (err?.status === 500) {
          this.message = 'Erreur serveur. Veuillez réessayer plus tard.';
        } else {
          this.message = err?.error?.detail || 'Échec de création du patient.';
        }
      },
      complete: () => {
        this.enCreation = false;
      },
    });
  }

  allerListe(): void {
    this.router.navigate(['/patients']);
  }
}

// #EbaJioloLewis
