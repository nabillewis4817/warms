import { Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { TokenErrorInfo } from '../composants/token-error-modal.component';

@Injectable({
  providedIn: 'root'
})
export class TokenErrorService {
  private errorSubject = new BehaviorSubject<TokenErrorInfo | null>(null);
  private visibleSubject = new BehaviorSubject<boolean>(false);
  
  public error$ = this.errorSubject.asObservable();
  public visible$ = this.visibleSubject.asObservable();

  constructor(private router: Router) {}

  showError(type: 'expired' | 'invalid' | 'missing' | 'network', details?: string): void {
    const errorInfo = this.createErrorInfo(type, details);
    this.errorSubject.next(errorInfo);
    this.visibleSubject.next(true);
  }

  hideError(): void {
    this.visibleSubject.next(false);
    setTimeout(() => {
      this.errorSubject.next(null);
    }, 300);
  }

  handleReconnect(): void {
    this.hideError();
    this.router.navigate(['/connexion']);
  }

  private createErrorInfo(type: 'expired' | 'invalid' | 'missing' | 'network', details?: string): TokenErrorInfo {
    const baseError = {
      type,
      details,
      recommendations: this.getRecommendations(type)
    };

    switch (type) {
      case 'expired':
        return {
          ...baseError,
          message: 'Votre session a expiré. Pour des raisons de sécurité, vous devez vous reconnecter.',
          details: details || 'Les tokens d\'authentification ont une durée de vie limitée pour protéger votre compte.'
        };
        
      case 'invalid':
        return {
          ...baseError,
          message: 'Votre token d\'authentification n\'est pas valide.',
          details: details || 'Le token a été modifié ou corrompu. Une nouvelle connexion est nécessaire.'
        };
        
      case 'missing':
        return {
          ...baseError,
          message: 'Aucune authentification détectée.',
          details: details || 'Vous devez être connecté pour accéder à cette ressource.'
        };
        
      case 'network':
        return {
          ...baseError,
          message: 'Problème de connexion au serveur.',
          details: details || 'Impossible de contacter le serveur pour vérifier votre authentification.'
        };
        
      default:
        return {
          ...baseError,
          message: 'Une erreur d\'authentification s\'est produite.',
          details: details || 'Une erreur inattendue est survenue lors de la vérification de votre identité.'
        };
    }
  }

  private getRecommendations(type: string): string[] {
    switch (type) {
      case 'expired':
        return [
          'Connectez-vous à nouveau avec vos identifiants',
          'Vérifiez que vous utilisez la bonne URL de connexion',
          'Contactez l\'administrateur si le problème persiste'
        ];
        
      case 'invalid':
        return [
          'Reconnectez-vous avec vos identifiants',
          'Évitez d\'ourir plusieurs sessions sur le même navigateur',
          'Assurez-vous que votre navigateur accepte les cookies'
        ];
        
      case 'missing':
        return [
          'Connectez-vous pour accéder à l\'application',
          'Vérifiez que vous êtes sur la bonne page de connexion',
          'Assurez-vous que votre compte est actif'
        ];
        
      case 'network':
        return [
          'Vérifiez votre connexion internet',
          'Essayez de rafraîchir la page',
          'Contactez le support technique si le problème persiste'
        ];
        
      default:
        return [
          'Essayez de vous reconnecter',
          'Vérifiez vos identifiants de connexion',
          'Contactez l\'administrateur système'
        ];
    }
  }
}
