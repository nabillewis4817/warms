import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { AbstractControl, FormBuilder, ReactiveFormsModule, ValidationErrors, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import QRCode from 'qrcode';

import { Patient, Patients } from '../../noyau/services/patients';
import { DialogueService } from '../../noyau/services/dialogue.service';
import { CapturePhoto } from '../../noyau/composants/capture-photo/capture-photo';

function telephoneValidator(control: AbstractControl): ValidationErrors | null {
  const valeur = control.value;
  if (!valeur) return null;
  const nettoye = String(valeur).replace(/[\s\-()]/g, '');
  return /^\+?[0-9]{8,15}$/.test(nettoye) ? null : { telephoneInvalide: true };
}

type CleEtape = 'identite' | 'contact' | 'medical' | 'compte' | 'photo';

@Component({
  selector: 'app-nouveau-patient',
  imports: [CommonModule, ReactiveFormsModule, CapturePhoto],
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
  photoFichier: File | null = null;
  photoTouchee = false;

  readonly etapes: { cle: CleEtape; label: string; icone: string }[] = [
    { cle: 'identite', label: 'Identité', icone: 'bi-person-vcard' },
    { cle: 'contact', label: 'Contact', icone: 'bi-telephone' },
    { cle: 'medical', label: 'Médical', icone: 'bi-heart-pulse' },
    { cle: 'compte', label: 'Compte', icone: 'bi-shield-lock' },
    { cle: 'photo', label: 'Photo', icone: 'bi-camera-fill' },
  ];
  etapeActive = 0;

  private readonly champsParEtape: Record<CleEtape, string[]> = {
    identite: ['prenom', 'nom', 'date_naissance', 'age', 'sexe'],
    contact: ['telephone', 'email', 'adresse'],
    medical: ['groupe_sanguin', 'taille_cm', 'poids_kg', 'symptomes', 'consultations_precedentes', 'allergies'],
    compte: ['username_patient', 'password_patient'],
    photo: [],
  };

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
    { value: 'inconnu', label: 'Inconnu' },
  ];

  form = this.fb.group({
    prenom: ['', Validators.required],
    nom: ['', Validators.required],
    date_naissance: [''],
    age: [''],
    telephone: ['', [telephoneValidator]],
    email: ['', [Validators.email]],
    adresse: [''],
    sexe: ['M'],
    taille_cm: [''],
    poids_kg: [''],
    symptomes: [''],
    consultations_precedentes: [''],
    allergies: [''],
    groupe_sanguin: ['inconnu'],
    username_patient: ['', Validators.required],
    password_patient: ['', [Validators.required, Validators.minLength(6)]],
  });

  get etapeCourante() {
    return this.etapes[this.etapeActive];
  }

  get estDernierEtape(): boolean {
    return this.etapeActive === this.etapes.length - 1;
  }

  etapeEstValide(index: number): boolean {
    const cle = this.etapes[index].cle;
    if (cle === 'photo') return this.photoFichier !== null;
    const champs = this.champsParEtape[cle];
    return champs.every((champ) => this.form.get(champ)?.valid ?? true);
  }

  allerEtape(index: number): void {
    // On ne permet de sauter en avant que si toutes les étapes intermédiaires sont valides.
    if (index > this.etapeActive) {
      for (let i = this.etapeActive; i < index; i++) {
        if (!this.etapeEstValide(i)) return;
      }
    }
    this.etapeActive = index;
  }

  etapeSuivante(): void {
    this.marquerEtapeTouchee(this.etapeActive);
    if (!this.etapeEstValide(this.etapeActive)) return;
    if (!this.estDernierEtape) {
      this.etapeActive++;
    }
  }

  etapePrecedente(): void {
    if (this.etapeActive > 0) {
      this.etapeActive--;
    }
  }

  private marquerEtapeTouchee(index: number): void {
    const cle = this.etapes[index].cle;
    if (cle === 'photo') {
      this.photoTouchee = true;
      return;
    }
    this.champsParEtape[cle].forEach((champ) => this.form.get(champ)?.markAsTouched());
  }

  champTouche(nom: string): boolean {
    const champ = this.form.get(nom);
    return !!champ && champ.touched && champ.invalid;
  }

  get initialesPatient(): string {
    const prenom = (this.form.get('prenom')?.value ?? '').charAt(0);
    const nom = (this.form.get('nom')?.value ?? '').charAt(0);
    return (prenom + nom).toUpperCase();
  }

  onPhotoChange(fichier: File | null): void {
    this.photoFichier = fichier;
  }

  creer(): void {
    this.etapes.forEach((_, index) => this.marquerEtapeTouchee(index));

    if (this.form.invalid || this.photoFichier === null) {
      this.etapeActive = this.etapes.findIndex((_, index) => !this.etapeEstValide(index));
      if (this.etapeActive < 0) this.etapeActive = 0;
      return;
    }

    this.enCreation = true;
    this.message = '';

    // Nettoyer le payload : ne jamais envoyer de chaîne vide pour un champ optionnel
    // (le backend rejette '' pour les champs date/entier, contrairement à une clé absente).
    const brut = this.form.getRawValue();
    const payload = Object.fromEntries(
      Object.entries(brut).filter(([, valeur]) => valeur !== null && valeur !== '')
    ) as any;

    this.patientsService.creer(payload, this.photoFichier).subscribe({
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
            password: creds.password,
          };
        }
        this.showSuccessModal = true;
      },
      error: (err) => {
        console.error('Erreur création patient:', err);
        this.enCreation = false;

        if (err?.status === 400) {
          const detail = err?.error?.detail;
          if (typeof detail === 'string') {
            if (detail.includes('existe déjà')) {
              this.message = 'Un patient avec ces informations existe déjà.';
            } else if (detail.includes('username')) {
              this.message = "Ce nom d'utilisateur patient est déjà utilisé.";
            } else if (detail.includes('obligatoires')) {
              this.message = "Le nom d'utilisateur et le mot de passe du patient sont obligatoires.";
            } else {
              this.message = detail;
            }
          } else {
            this.message = 'Erreur de validation : ' + JSON.stringify(detail);
          }
        } else if (err?.status === 401) {
          this.message = "Erreur d'authentification. Veuillez vous reconnecter.";
        } else if (err?.status === 403) {
          this.message = "Vous n'avez pas les permissions pour créer un patient.";
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
      username_patient: '',
      password_patient: '',
    });
    this.message = '';
    this.patientCree = null;
    this.qrImageData = '';
    this.photoFichier = null;
    this.photoTouchee = false;
    this.etapeActive = 0;
  }

  creerAutrePatient(): void {
    this.resetForm();
    this.showSuccessModal = false;
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  closeSuccessModal(): void {
    this.showSuccessModal = false;
  }

  goToListeCarnets(): void {
    this.showSuccessModal = false;
    this.router.navigate(['/patients']);
  }
}

// #EbaJioloLewis
