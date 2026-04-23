import { CommonModule } from '@angular/common';
import { Component, HostListener } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs';

import { Authentification } from './noyau/services/authentification';
import { DialogueModal } from './noyau/composants/dialogue-modal/dialogue-modal';
import { DialogueComponent } from './noyau/components/dialogue/dialogue';
import { Messagerie } from './noyau/services/messagerie';
import { ThemeService } from './noyau/services/theme';
import { TraductionService } from './noyau/services/traduction';

@Component({
  selector: 'app-root',
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive, DialogueModal, DialogueComponent],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {
  badges = { rappel: 0, message: 0, critique: 0 };
  menuActionsOuvert = false;
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

  basculerMenuActions(): void {
    this.menuActionsOuvert = !this.menuActionsOuvert;
  }

  actionRapide(action: string): void {
    this.menuActionsOuvert = false;
    
    switch (action) {
      case 'nouveau-patient':
        this.router.navigate(['/patients/nouveau']);
        break;
      case 'nouveau-rdv':
        this.router.navigate(['/rendez-vous/nouveau']);
        break;
      case 'statistiques':
        this.router.navigate(['/statistiques']);
        break;
      case 'messagerie':
        this.router.navigate(['/messagerie']);
        break;
      case 'carnets':
        this.router.navigate(['/carnets']);
        break;
      default:
        this.router.navigate(['/patients/nouveau']);
    }
  }

  ouvrirWarms(): void {
    // Rediriger vers la page IA WARMS
    this.router.navigate(['/ia-warms']).catch(() => {
      this.router.navigate(['/innovations/ia-warms']);
    });
  }

  // Fermer le menu lors d'un clic à l'extérieur
  @HostListener('document:click', ['$event'])
  onClickOutside(event: Event): void {
    const target = event.target as HTMLElement;
    if (!target.closest('.quick-actions-dropdown')) {
      this.menuActionsOuvert = false;
    }
  }
}

// #EbaJioloLewis
