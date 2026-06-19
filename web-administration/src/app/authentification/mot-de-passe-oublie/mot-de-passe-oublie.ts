import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { Authentification } from '../../noyau/services/authentification';

type EtapeMdp = 'email' | 'reset' | 'succes';

@Component({
  selector: 'app-mot-de-passe-oublie',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './mot-de-passe-oublie.html',
  styleUrl: './mot-de-passe-oublie.scss',
})
export class MotDePasseOublie {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(Authentification);

  etape: EtapeMdp = 'email';
  tokenRecu = '';
  message = '';
  erreur = '';
  loading = false;
  afficherMotDePasse = false;
  tokenCopie = false;

  formEmail = this.fb.group({ email: ['', [Validators.required, Validators.email]] });
  formReset = this.fb.group({
    token: ['', Validators.required],
    nouveau_mot_de_passe: ['', [Validators.required, Validators.minLength(8)]],
    confirmation: ['', Validators.required],
  });

  get motsDePasseDifferents(): boolean {
    const v = this.formReset.value;
    return !!v.nouveau_mot_de_passe && !!v.confirmation && v.nouveau_mot_de_passe !== v.confirmation;
  }

  demanderToken(): void {
    if (this.formEmail.invalid) {
      this.formEmail.markAllAsTouched();
      return;
    }
    this.loading = true;
    this.message = '';
    this.erreur = '';
    this.auth.forgotPassword(this.formEmail.value.email!).subscribe({
      next: (res) => {
        this.tokenRecu = res.token ?? '';
        this.formReset.patchValue({ token: this.tokenRecu });
        this.message = res.detail;
        this.loading = false;
        this.etape = 'reset';
      },
      error: () => {
        this.erreur = 'Erreur lors de la demande de réinitialisation. Vérifiez votre adresse email.';
        this.loading = false;
      },
    });
  }

  copierToken(): void {
    if (!this.tokenRecu) return;
    navigator.clipboard?.writeText(this.tokenRecu).then(() => {
      this.tokenCopie = true;
      setTimeout(() => (this.tokenCopie = false), 2000);
    });
  }

  reset(): void {
    if (this.formReset.invalid || this.motsDePasseDifferents) {
      this.formReset.markAllAsTouched();
      if (this.motsDePasseDifferents) {
        this.erreur = 'Les mots de passe ne correspondent pas.';
      }
      return;
    }
    this.loading = true;
    this.message = '';
    this.erreur = '';
    const v = this.formReset.getRawValue();
    this.auth.resetPassword(v.token || '', v.nouveau_mot_de_passe || '').subscribe({
      next: () => {
        this.loading = false;
        this.etape = 'succes';
      },
      error: (err) => {
        this.loading = false;
        this.erreur = err?.error?.detail || 'Échec de la réinitialisation. Le token est peut-être invalide ou expiré.';
      },
    });
  }

  revenirEtapeEmail(): void {
    this.etape = 'email';
    this.message = '';
    this.erreur = '';
  }
}

// #EbaJioloLewis
