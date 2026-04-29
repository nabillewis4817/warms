import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';

import { Authentification } from '../services/authentification';

export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(Authentification);
  const router = inject(Router);
  
  // Ne pas ajouter de token pour les requêtes d'authentification
  if (req.url.includes('/auth/token/') || req.url.includes('/auth/register/') || 
      req.url.includes('/auth/forgot-password/') || req.url.includes('/auth/reset-password/')) {
    return next(req);
  }

  const token = auth.tokenAccess();
  if (!token) {
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
      // Si erreur 401, déconnecter et rediriger vers connexion
      if (error.status === 401) {
        auth.deconnexion();
        router.navigate(['/connexion']);
      }
      return throwError(() => error);
    })
  );
};

// #EbaJioloLewis
