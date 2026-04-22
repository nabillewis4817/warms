import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs';

import { Authentification } from './noyau/services/authentification';
import { Messagerie } from './noyau/services/messagerie';
import { ThemeService } from './noyau/services/theme';
import { TraductionService } from './noyau/services/traduction';

@Component({
  selector: 'app-root',
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {
  badges = { rappel: 0, message: 0, critique: 0 };
  constructor(
    readonly themeService: ThemeService,
    readonly traductionService: TraductionService,
    readonly authService: Authentification,
    private readonly messagerie: Messagerie,
    private readonly router: Router
  ) {
    this.router.events
      .pipe(filter((event) => event instanceof NavigationEnd))
      .subscribe(() => {
        if (this.authService.estConnecte() && !this.authService.utilisateur()) {
          this.authService.chargerProfil().subscribe({
            next: (profil) => {
              this.themeService.appliquer(!!(profil as any).mode_sombre);
              this.traductionService.definirLangue(((profil as any).langue_interface ?? 'fr') as 'fr' | 'en');
            },
          });
        }
        if (this.authService.estConnecte()) {
          this.messagerie.badges().subscribe({ next: (b) => (this.badges = b) });
        }
      });
  }

  get estPageConnexion(): boolean {
    return this.router.url.startsWith('/connexion');
  }

  changerLangue(langue: 'fr' | 'en'): void {
    this.traductionService.definirLangue(langue);
  }

  basculerTheme(event: Event): void {
    const cible = event.target as HTMLInputElement;
    this.themeService.appliquer(cible.checked);
  }

  actionRapide(): void {
    this.router.navigate(['/patients/nouveau']);
  }

  ouvrirWarms(): void {
    this.router.navigate(['/statistiques']);
  }
}

// #EbaJioloLewis
