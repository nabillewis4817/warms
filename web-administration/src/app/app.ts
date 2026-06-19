import { CommonModule } from '@angular/common';
import { Component, HostListener, inject } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { Observable, filter } from 'rxjs';

import { Authentification } from './noyau/services/authentification';
import { DialogueModal } from './noyau/composants/dialogue-modal/dialogue-modal';
import { DialogueComponent } from './noyau/components/dialogue/dialogue';
import { Messagerie } from './noyau/services/messagerie';
import { NotificationsService } from './noyau/services/notifications.service';
import { ThemeService } from './noyau/services/theme';
import { TraductionService } from './noyau/services/traduction';
import { DateTimeService } from './noyau/services/datetime.service';
import { AlerteService } from './noyau/services/alerte.service';
import { SelecteurPatientService } from './noyau/services/selecteur-patient.service';

import { AlerteComponent } from './noyau/composants/alerte/alerte.component';
import { GlobalTokenErrorHandlerComponent } from './noyau/composants/global-token-error-handler.component';

@Component({
  selector: 'app-root',
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive, DialogueModal, DialogueComponent, AlerteComponent, GlobalTokenErrorHandlerComponent],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {
  readonly selecteurSvc = inject(SelecteurPatientService);

  badges = { rappel: 0, message: 0, critique: 0, total: 0 };
  menuActionsOuvert = false;
  showNotificationPanel = false;
  notificationsEnabled = true;
  showLogoutModal = false;
  
  // Propriétés pour la date/heure
  showExtendedDateTime = false;
  formattedDateTime$?: Observable<string>;
  formattedDateExtended$?: Observable<string>;
  timeBasedGreeting = '';
  
  constructor(
    readonly themeService: ThemeService,
    readonly traductionService: TraductionService,
    readonly authService: Authentification,
    private readonly messagerie: Messagerie,
    private readonly notificationsService: NotificationsService,
    private readonly router: Router,
    readonly dateTimeService: DateTimeService,
    private readonly alerteService: AlerteService
  ) {
    // Initialiser les propriétés DateTime après l'injection
    this.formattedDateTime$ = this.dateTimeService.formattedDateTime$;
    this.formattedDateExtended$ = this.dateTimeService.formattedDateExtended$;
    this.timeBasedGreeting = this.dateTimeService.getTimeBasedGreeting();
    this.themeService.restaurerDepuisStockageLocal();
    this.router.events
      .pipe(filter((event) => event instanceof NavigationEnd))
      .subscribe(() => {
        if (this.estPageConnexion || !this.authService.estConnecte()) {
          return;
        }
        if (!this.authService.utilisateur()) {
          this.authService.chargerProfil().subscribe({
            next: (profil) => {
              this.themeService.appliquer(!!(profil as any).mode_sombre);
              this.themeService.appliquerCouleur(((profil as any).theme_couleur ?? 'bleu') as any);
              this.traductionService.definirLangue(((profil as any).langue_interface ?? 'fr') as 'fr' | 'en');
            },
          });
        }
        this.messagerie.badges().subscribe({
          next: (b) => (this.badges = { ...b, total: b.message + b.critique + b.rappel })
        });
        this.notificationsService.badges$.subscribe({ next: (b) => (this.badges = b) });
      });
  }

  get initialesUtilisateur(): string {
    const u = this.authService.utilisateur();
    if (!u) return '?';
    return ((u.prenom?.charAt(0) ?? '') + (u.nom?.charAt(0) ?? '')).toUpperCase() || '?';
  }

  get roleLabelUtilisateur(): string {
    const roles: Record<string, string> = {
      chirurgien_dentiste: 'Chirurgien-Dentiste',
      secretaire: 'Secrétaire',
      infirmiere: 'Infirmière',
      assistant: 'Assistant',
      admin: 'Administrateur',
      patient: 'Patient',
    };
    const role = this.authService.utilisateur()?.role ?? '';
    return roles[role] || role;
  }

  get estPageConnexion(): boolean {
    return this.router.url === '/' ||
           this.router.url.startsWith('/connexion') ||
           this.router.url.startsWith('/inscription') ||
           this.router.url.startsWith('/mot-de-passe-oublie');
  }

  changerLangue(langue: 'fr' | 'en'): void {
    this.traductionService.definirLangue(langue);
  }

  basculerTheme(event: any): void {
    this.themeService.appliquer(event.target.checked);
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

  toggleNotifications(): void {
    this.showNotificationPanel = !this.showNotificationPanel;
    this.notificationsEnabled = !this.notificationsEnabled;
  }

  clearAllNotifications(): void {
    this.notificationsService.resetBadges();
    this.showNotificationPanel = false;
  }

  testNotificationSound(): void {
    this.notificationsService.testNotificationSound();
  }

  seDeconnecter(): void {
    // Afficher la fenêtre de confirmation stylisée
    this.showLogoutModal = true;
  }

  closeLogoutModal(): void {
    this.showLogoutModal = false;
  }

  confirmLogout(): void {
    // Effacer les données d'authentification
    this.authService.deconnexion();
    
    // Fermer la fenêtre modale
    this.showLogoutModal = false;
    
    this.router.navigate(['/']);
  }

  // Fermer le menu lors d'un clic à l'extérieur
  @HostListener('document:click', ['$event'])
  onClickOutside(event: Event): void {
    const target = event.target as HTMLElement;
    if (!target.closest('.quick-actions-dropdown') && !target.closest('.notification-controls')) {
      this.menuActionsOuvert = false;
      this.showNotificationPanel = false;
    }
  }
}

// #EbaJioloLewis
