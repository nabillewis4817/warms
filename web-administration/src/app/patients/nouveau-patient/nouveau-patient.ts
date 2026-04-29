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
  patientCredentials: { username: string; password: string } | null = null;
  enCreation = false;
  qrImageData = '';
  showPassword = false;
  showSuccessModal = false;
  
  // Options pour le groupe sanguin
  groupesSanguins = [
    { value: 'A+', label: 'A+' },
    { value: 'A-', label: 'A-' },
    { value: 'B+', label: 'B+' },
    { value: 'B-', label: 'B-' },
    { value: 'AB+', label: 'AB+' },
    { value: 'AB-', label: 'AB-' },
    { value: 'O+', label: 'O+' },
    { value: 'O-', label: 'O-' },
    { value: 'inconnu', label: 'Inconnu' }
  ];

  form = this.fb.group({
    prenom: ['', Validators.required],
    nom: ['', Validators.required],
    date_naissance: [''],
    age: [''],
    telephone: ['', [Validators.pattern(/^\+237\d{9}$/)]],
    email: [''],
    adresse: [''],
    sexe: ['M'],
    taille_cm: [''],
    poids_kg: [''],
    symptomes: [''],
    consultations_precedentes: [''],
    allergies: [''],
    groupe_sanguin: ['inconnu'],
    derniere_consultation_date: [''],
    derniere_consultation_lieu: [''],
    derniere_consultation_details: [''],
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
          this.patientCredentials = {
            username: creds.username,
            password: creds.password
          };
        }
        
        // Afficher la modale de succès
        this.showSuccessModal = true;
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

  togglePassword(): void {
    this.showPassword = !this.showPassword;
  }

  resetForm(): void {
    this.form.reset({
      prenom: '',
      nom: '',
      date_naissance: '',
      age: '',
      telephone: '',
      email: '',
      adresse: '',
      sexe: 'M',
      taille_cm: '',
      poids_kg: '',
      symptomes: '',
      consultations_precedentes: '',
      allergies: '',
      groupe_sanguin: 'inconnu',
      derniere_consultation_date: '',
      derniere_consultation_lieu: '',
      derniere_consultation_details: '',
      username_patient: '',
      password_patient: ''
    });
    this.message = '';
    this.patientCree = null;
    this.qrImageData = '';
  }

  creerAutrePatient(): void {
    this.resetForm();
    // Scroll vers le haut du formulaire
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  closeSuccessModal(): void {
    this.showSuccessModal = false;
  }

  goToListeCarnets(): void {
    this.showSuccessModal = false;
    // Redirection vers la liste des carnets
    this.router.navigate(['/patients']);
  }
}

// #EbaJioloLewis
