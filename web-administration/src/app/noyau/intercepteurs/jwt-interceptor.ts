import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { throwError, of } from 'rxjs';
import { catchError, switchMap } from 'rxjs/operators';

import { Authentification } from '../services/authentification';
import { TokenErrorService } from '../services/token-error.service';

export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(Authentification);
  const router = inject(Router);
  const tokenErrorService = inject(TokenErrorService);
  
  // Ne pas ajouter de token pour les requêtes d'authentification
  if (req.url.includes('/auth/token/') || req.url.includes('/auth/register/') || 
      req.url.includes('/auth/forgot-password/') || req.url.includes('/auth/reset-password/')) {
    return next(req);
  }

  console.log('DEBUG: JWT Interceptor - URL:', req.url);
  console.log('DEBUG: JWT Interceptor - Token exists:', !!auth.tokenAccess());

  const token = auth.tokenAccess();
  if (!token) {
    // Afficher la fenêtre d'erreur stylisée pour token manquant
    tokenErrorService.showError('missing', 'Aucun token d\'authentification trouvé dans votre session.');
    // Si pas de token et on n'est pas déjà sur la page de connexion, rediriger
    if (router.url !== '/connexion') {
      router.navigate(['/connexion']);
    }
    return next(req);
  }

  const clone = req.clone({
    setHeaders: {
      Authorization: `Bearer ${token}`,
    },
  });

  return next(clone).pipe(
    catchError((error) => {
      // Si erreur 401, essayer de rafraîchir le token
      if (error.status === 401) {
        // Afficher la fenêtre d'erreur stylisée pour token expiré
        tokenErrorService.showError('expired', 'Votre session a expiré. Tentative de rafraîchissement automatique...');
        
        return auth.rafraichirAccessToken().pipe(
          switchMap((newTokens) => {
            if (newTokens && newTokens.access) {
              const retryReq = req.clone({
                setHeaders: {
                  Authorization: `Bearer ${newTokens.access}`,
                },
              });
              return next(retryReq);
            } else {
              // Le rafraîchissement a échoué, afficher l'erreur et rediriger
              tokenErrorService.showError('expired', 'Le rafraîchissement automatique a échoué. Veuillez vous reconnecter.');
              auth.deconnexion();
              router.navigate(['/connexion']);
              return throwError(() => new Error('Session expired'));
            }
          }),
          catchError((refreshError) => {
            // Erreur lors du rafraîchissement
            tokenErrorService.showError('expired', 'Impossible de rafraîchir votre session. Veuillez vous reconnecter.');
            auth.deconnexion();
            router.navigate(['/connexion']);
            return throwError(() => new Error('Session expired'));
          })
        );
      }
      
      // Pour les erreurs réseau (500, 0, etc.)
      if (error.status >= 500 || error.status === 0) {
        tokenErrorService.showError('network', `Erreur serveur: ${error.status || 'Connexion perdue'}`);
      }
      
      return throwError(() => error);
    })
  );
};

// #EbaJioloLewis
