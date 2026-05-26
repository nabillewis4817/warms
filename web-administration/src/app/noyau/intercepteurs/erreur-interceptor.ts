import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, switchMap, throwError } from 'rxjs';

import { Authentification } from '../services/authentification';

export const erreurInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(Authentification);
  const router = inject(Router);
  const estEndpointAuth =
    req.url.includes('/auth/token/') ||
    req.url.includes('/auth/token/refresh/') ||
    req.url.includes('/auth/register/');

  return next(req).pipe(
    catchError((err) => {
      if (err?.status === 401 && !estEndpointAuth && auth.tokenRefresh()) {
        return auth.rafraichirAccessToken().pipe(
          switchMap((tokens: { access?: string }) => {
            const access = tokens?.access ?? auth.tokenAccess();
            if (!access) {
              return throwError(() => err);
            }
            return next(
              req.clone({ setHeaders: { Authorization: `Bearer ${access}` } })
            );
          }),
          catchError(() => {
            if (router.url !== '/connexion') {
              auth.deconnexion();
              router.navigate(['/connexion']);
            }
            return throwError(() => err);
          })
        );
      }

      if (err?.status === 401 && !estEndpointAuth && router.url !== '/connexion') {
        auth.deconnexion();
        router.navigate(['/connexion']);
      }

      return throwError(() => err);
    })
  );
};

// #EbaJioloLewis
