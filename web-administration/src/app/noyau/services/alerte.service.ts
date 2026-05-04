import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

export interface AlerteMessage {
  titre: string;
  message: string;
  type: 'erreur' | 'warning' | 'success' | 'info';
  details?: string;
  action?: string;
  boutonText?: string;
  icone?: string;
}

@Injectable({
  providedIn: 'root'
})
export class AlerteService {
  private alerteSubject = new BehaviorSubject<AlerteMessage | null>(null);
  public alerte$ = this.alerteSubject.asObservable();

  afficherAlerte(alerte: AlerteMessage): void {
    this.alerteSubject.next(alerte);
  }

  afficherErreur(message: string, details?: string, action?: string): void {
    this.afficherAlerte({
      titre: 'Erreur',
      message: message,
      type: 'erreur',
      details: details,
      action: action,
      boutonText: 'Compris!',
      icone: 'bi-x-circle-fill'
    });
  }

  afficherWarning(message: string, details?: string): void {
    this.afficherAlerte({
      titre: 'Attention',
      message: message,
      type: 'warning',
      details: details,
      boutonText: 'Compris!',
      icone: 'bi-exclamation-triangle-fill'
    });
  }

  afficherSuccess(message: string): void {
    this.afficherAlerte({
      titre: 'Succès',
      message: message,
      type: 'success',
      boutonText: 'OK',
      icone: 'bi-check-circle-fill'
    });
  }

  afficherInfo(message: string): void {
    this.afficherAlerte({
      titre: 'Information',
      message: message,
      type: 'info',
      boutonText: 'Compris!',
      icone: 'bi-info-circle-fill'
    });
  }

  afficherPermissionRefusee(role: string, action: string): void {
    this.afficherAlerte({
      titre: 'Permission Refusée',
      message: `En tant que ${role}, vous ne pouvez pas ${action}.`,
      type: 'erreur',
      details: `Seul un utilisateur avec des permissions supérieures peut effectuer cette action.`,
      action: 'Vérifiez vos permissions ou contactez un administrateur.',
      boutonText: 'Compris!',
      icone: 'bi-shield-x'
    });
  }

  afficherPermissionInsuffise(roleActuel: string, roleRequis: string, action: string): void {
    this.afficherAlerte({
      titre: 'Permissions Insuffisantes',
      message: `Action requise : ${action}`,
      type: 'erreur',
      details: `Votre rôle actuel (${roleActuel}) ne vous permet pas d'effectuer cette action.`,
      action: `Rôle requis : ${roleRequis}. Veuillez contacter un administrateur.`,
      boutonText: 'Compris!',
      icone: 'bi-lock-fill'
    });
  }

  afficherErreurTechnique(message: string, erreur?: any): void {
    const details = erreur ? 
      `Erreur technique: ${erreur.status || 'Inconnue'} - ${erreur.message || erreur.statusText || 'Détails non disponibles'}` : 
      'Détails techniques non disponibles';
      
    this.afficherAlerte({
      titre: 'Erreur Technique',
      message: message,
      type: 'erreur',
      details: details,
      action: 'Veuillez réessayer plus tard ou contacter le support technique.',
      boutonText: 'Compris!',
      icone: 'bi-gear-fill'
    });
  }

  afficherErreurConnexion(ressource: string): void {
    this.afficherAlerte({
      titre: 'Erreur de Connexion',
      message: `Impossible de se connecter à ${ressource}`,
      type: 'erreur',
      details: 'Vérifiez votre connexion internet ou si le serveur est disponible.',
      action: 'Si le problème persiste, contactez l\'administrateur système.',
      boutonText: 'Compris!',
      icone: 'bi-wifi-off'
    });
  }

  afficherErreurValidation(champs: string[]): void {
    const champsListe = champs.map(champ => `• ${champ}`).join('\n');
    this.afficherAlerte({
      titre: 'Erreur de Validation',
      message: 'Veuillez corriger les erreurs suivantes :',
      type: 'erreur',
      details: champsListe,
      action: 'Les champs obligatoires doivent être remplis correctement.',
      boutonText: 'Compris!',
      icone: 'bi-clipboard-x'
    });
  }

  fermerAlerte(): void {
    this.alerteSubject.next(null);
  }
}
