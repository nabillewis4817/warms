import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';

import { Authentification } from '../services/authentification';

export const erreurInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(Authentification);
  const router = inject(Router);
  return next(req).pipe(
    catchError((err) => {
      if (err?.status === 401) {
        auth.deconnexion();
        router.navigate(['/connexion']);
      }
      return throwError(() => err);
    })
  );
};

// #EbaJioloLewis
