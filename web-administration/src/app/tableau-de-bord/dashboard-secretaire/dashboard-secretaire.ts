import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';

import { Authentification } from '../../noyau/services/authentification';
import { DateTimeService } from '../../noyau/services/datetime.service';
import { DashboardService, DashboardStats } from '../../noyau/services/dashboard';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-dashboard-secretaire',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './dashboard-secretaire.html',
  styleUrls: ['./dashboard-secretaire.scss'],
})
export class DashboardSecretaire implements OnInit {
  readonly auth = inject(Authentification);
  private readonly router = inject(Router);
  readonly dateTimeService = inject(DateTimeService);
  private readonly dashboardService = inject(DashboardService);
  private readonly http = inject(HttpClient);

  dashboardStats: DashboardStats | null = null;
  chargement = false;

  nouveauPersonnel = {
    prenom: '',
    nom: '',
    email: '',
    telephone: '',
    role: 'infirmiere',
    service: '',
    specialite: '',
  };

  motDePasseGenere = '';
  usernameGenere = '';
  soumissionEnCours = false;
  soumissionReussie = false;
  erreurSoumission = '';

  get salutation(): string {
    return this.dateTimeService.getTimeBasedGreeting();
  }

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement = true;
    this.dashboardService.getDashboardStats().subscribe({
      next: (data) => {
        this.dashboardStats = data;
        this.chargement = false;
      },
      error: () => {
        this.chargement = false;
      },
    });
  }

  genererIdentifiants(): void {
    const prenom = this.normaliserTexte(this.nouveauPersonnel.prenom);
    const nom = this.normaliserTexte(this.nouveauPersonnel.nom);
    this.usernameGenere = `${prenom}.${nom}`;
    this.motDePasseGenere = this.genererMotDePasse();
  }

  private normaliserTexte(texte: string): string {
    return texte
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/\s+/g, '.');
  }

  private genererMotDePasse(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let mdp = '';
    for (let i = 0; i < 10; i++) {
      mdp += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return mdp.charAt(0).toUpperCase() + mdp.slice(1);
  }

  soumettreNouveauPersonnel(): void {
    if (!this.usernameGenere || this.soumissionEnCours) return;
    this.soumissionEnCours = true;
    this.erreurSoumission = '';

    const payload = {
      ...this.nouveauPersonnel,
      username: this.usernameGenere,
      mot_de_passe_temporaire: this.motDePasseGenere,
    };

    this.http.post(`${environment.apiBaseUrl}/personnel/demandes/`, payload).subscribe({
      next: () => {
        this.soumissionEnCours = false;
        this.soumissionReussie = true;
      },
      error: (err) => {
        this.soumissionEnCours = false;
        this.erreurSoumission =
          err?.error?.detail ?? "Une erreur s'est produite. Veuillez réessayer.";
      },
    });
  }
}
