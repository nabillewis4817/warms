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
    if (this.form.invalid) {
      // Marquer tous les champs comme touchés pour afficher les erreurs
      Object.values(this.form.controls).forEach(control => {
        control.markAsTouched();
      });
      return;
    }
    
    this.loading = true;
    this.message = '';
    
    this.auth.register(this.form.getRawValue() as any).subscribe({
      next: (response) => {
        this.loading = false;
        this.message = `Inscription réussie ! Bienvenue ${response.username}. Redirection vers la connexion...`;
        
        // Rediriger après 2 secondes pour permettre à l'utilisateur de voir le message
        setTimeout(() => {
          this.router.navigate(['/connexion']);
        }, 2000);
      },
      error: (err) => {
        this.loading = false;
        console.error('Erreur d\'inscription:', err);
        
        // Gérer différents types d'erreurs
        if (err.status === 400) {
          this.message = "Les informations fournies sont invalides. Veuillez vérifier vos données.";
        } else if (err.status === 409) {
          this.message = "Ce nom d'utilisateur ou cet email existe déjà.";
        } else if (err.status === 500) {
          this.message = "Erreur serveur. Veuillez réessayer plus tard.";
        } else {
          this.message = "Impossible d'inscrire cet utilisateur. Veuillez réessayer.";
        }
      },
    });
  }
}

// #EbaJioloLewis
