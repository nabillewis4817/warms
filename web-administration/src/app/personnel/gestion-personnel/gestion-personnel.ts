import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';

import { Authentification } from '../../noyau/services/authentification';
import { PersonnelCompte, PersonnelService } from '../../noyau/services/personnel.service';
import { CapturePhoto } from '../../noyau/composants/capture-photo/capture-photo';

@Component({
  selector: 'app-gestion-personnel',
  imports: [CommonModule, ReactiveFormsModule, CapturePhoto],
  templateUrl: './gestion-personnel.html',
  styleUrl: './gestion-personnel.scss',
})
export class GestionPersonnel implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly personnelService = inject(PersonnelService);
  private readonly router = inject(Router);
  readonly auth = inject(Authentification);
  comptes: PersonnelCompte[] = [];
  message = '';
  photoFichier: File | null = null;
  photoTouchee = false;

  form = this.fb.group({
    username: ['', Validators.required],
    first_name: ['', Validators.required],
    last_name: ['', Validators.required],
    email: ['', Validators.required],
    telephone: [''],
    role: ['infirmiere', Validators.required],
    password: [''],
  });

  ngOnInit(): void {
    this.recharger();
  }

  recharger(): void {
    this.personnelService.lister().subscribe({
      next: (items) => (this.comptes = items),
    });
  }

  onPhotoChange(fichier: File | null): void {
    this.photoFichier = fichier;
  }

  get initiales(): string {
    const prenom = (this.form.get('first_name')?.value ?? '').charAt(0);
    const nom = (this.form.get('last_name')?.value ?? '').charAt(0);
    return (prenom + nom).toUpperCase();
  }

  creer(): void {
    this.photoTouchee = true;
    if (this.form.invalid || !this.photoFichier) return;

    this.personnelService.creer(this.form.getRawValue(), this.photoFichier).subscribe({
      next: () => {
        this.message = 'Compte personnel créé.';
        this.form.reset({ role: 'infirmiere' });
        this.photoFichier = null;
        this.photoTouchee = false;
        this.recharger();
      },
      error: () => (this.message = 'Erreur de création.'),
    });
  }

  valider(compte: PersonnelCompte): void {
    this.personnelService.valider(compte.id).subscribe({
      next: () => this.router.navigate(['/tableau-de-bord']),
      error: () => (this.message = 'Validation refusée (réservé au chirurgien).'),
    });
  }

  supprimer(compte: PersonnelCompte): void {
    this.personnelService.supprimer(compte.id).subscribe({
      next: () => this.recharger(),
      error: () => (this.message = 'Suppression impossible.'),
    });
  }

  get estChirurgien(): boolean {
    return this.auth.utilisateur()?.role === 'chirurgien_dentiste';
  }
}

// #EbaJioloLewis
