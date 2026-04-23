import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';

import { Authentification } from '../../noyau/services/authentification';

@Component({
  selector: 'app-inscription',
  imports: [CommonModule, ReactiveFormsModule, RouterLink],
  templateUrl: './inscription.html',
  styleUrl: './inscription.scss',
})
export class Inscription {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(Authentification);
  private readonly router = inject(Router);
  message = '';
  loading = false;

  form = this.fb.group({
    username: ['', Validators.required],
    email: ['', [Validators.required, Validators.email]],
    first_name: ['', Validators.required],
    last_name: ['', Validators.required],
    telephone: [''],
    role: ['patient', Validators.required],
    password: ['', [Validators.required, Validators.minLength(8)]],
  });

  soumettre(): void {
    if (this.form.invalid) return;
    this.loading = true;
    this.message = '';
    this.auth.register(this.form.getRawValue() as any).subscribe({
      next: () => {
        this.loading = false;
        this.router.navigate(['/connexion']);
      },
      error: (err) => {
        this.loading = false;
        this.message = "Impossible d'inscrire cet utilisateur.";
      },
    });
  }
}

// #EbaJioloLewis
