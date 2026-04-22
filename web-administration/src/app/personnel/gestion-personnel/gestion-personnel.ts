import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';

import { Authentification } from '../../noyau/services/authentification';
import { PersonnelCompte, PersonnelService } from '../../noyau/services/personnel';

@Component({
  selector: 'app-gestion-personnel',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './gestion-personnel.html',
  styleUrl: './gestion-personnel.scss',
})
export class GestionPersonnel implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly personnelService = inject(PersonnelService);
  readonly auth = inject(Authentification);
  comptes: PersonnelCompte[] = [];
  message = '';

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

  creer(): void {
    if (this.form.invalid) return;
    this.personnelService.creer(this.form.getRawValue()).subscribe({
      next: () => {
        this.message = 'Compte personnel créé.';
        this.form.reset({ role: 'infirmiere' });
        this.recharger();
      },
      error: () => (this.message = 'Erreur de création.'),
    });
  }

  valider(compte: PersonnelCompte): void {
    this.personnelService.valider(compte.id).subscribe({
      next: () => this.recharger(),
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
