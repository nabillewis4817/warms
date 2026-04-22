import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, switchMap, throwError } from 'rxjs';

import { Authentification } from '../services/authentification';

export const erreurInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(Authentification);
  const router = inject(Router);
  return next(req).pipe(
    catchError((err) => {
      const estEndpointAuth = req.url.includes('/auth/token/');
      if (err?.status === 401 && !estEndpointAuth && auth.tokenRefresh()) {
        return auth.rafraichirAccessToken().pipe(
          switchMap(() => {
            const access = auth.tokenAccess();
            const retryReq = access
              ? req.clone({ setHeaders: { Authorization: `Bearer ${access}` } })
              : req;
            return next(retryReq);
          }),
          catchError((refreshErr) => {
            auth.deconnexion();
            router.navigate(['/connexion']);
            return throwError(() => refreshErr);
          })
        );
      }
      if (err?.status === 401) {
        auth.deconnexion();
        router.navigate(['/connexion']);
      }
      return throwError(() => err);
    })
  );
};

// #EbaJioloLewis
