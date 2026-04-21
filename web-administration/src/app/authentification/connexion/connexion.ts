import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';

import { Authentification } from '../../noyau/services/authentification';

@Component({
  selector: 'app-connexion',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './connexion.html',
  styleUrl: './connexion.scss',
})
export class Connexion {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(Authentification);
  private readonly router = inject(Router);

  erreur = '';
  enCours = false;

  form = this.fb.group({
    username: ['', [Validators.required]],
    password: ['', [Validators.required]],
  });

  soumettre(): void {
    if (this.form.invalid) return;
    this.enCours = true;
    this.erreur = '';
    const v = this.form.getRawValue();
    this.auth.connexion(v.username!, v.password!).subscribe({
      next: () => {
        this.auth.chargerProfil().subscribe({
          next: () => this.router.navigate(['/tableau-de-bord']),
          error: () => {
            this.router.navigate(['/tableau-de-bord']);
          },
        });
      },
      error: () => {
        this.erreur = "Identifiants invalides. Vérifie ton username et mot de passe.";
        this.enCours = false;
      },
      complete: () => {
        this.enCours = false;
      },
    });
  }
}

// #EbaJioloLewis
