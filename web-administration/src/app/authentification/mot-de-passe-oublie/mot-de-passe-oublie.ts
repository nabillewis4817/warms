import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { Authentification } from '../../noyau/services/authentification';

@Component({
  selector: 'app-mot-de-passe-oublie',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './mot-de-passe-oublie.html',
  styleUrl: './mot-de-passe-oublie.scss',
})
export class MotDePasseOublie {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(Authentification);
  tokenRecu = '';
  message = '';

  formEmail = this.fb.group({ email: ['', [Validators.required, Validators.email]] });
  formReset = this.fb.group({
    token: [''],
    nouveau_mot_de_passe: ['', [Validators.required, Validators.minLength(8)]],
  });

  demanderToken(): void {
    if (this.formEmail.invalid) return;
    this.auth.forgotPassword(this.formEmail.value.email!).subscribe({
      next: (res) => {
        this.tokenRecu = res.token ?? '';
        this.formReset.patchValue({ token: this.tokenRecu });
        this.message = res.detail;
      },
    });
  }

  reset(): void {
    if (this.formReset.invalid) return;
    const v = this.formReset.getRawValue();
    this.auth.resetPassword(v.token || '', v.nouveau_mot_de_passe || '').subscribe({
      next: (res) => (this.message = res.detail),
      error: () => (this.message = 'Échec de réinitialisation.'),
    });
  }
}

// #EbaJioloLewis
