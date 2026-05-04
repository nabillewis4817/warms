import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent, HttpResponse } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable, throwError, of } from 'rxjs';
import { catchError, switchMap } from 'rxjs/operators';
import { Authentification } from '../services/authentification';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(private auth: Authentification) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    // Ne pas intercepter les requêtes d'authentification
    if (req.url.includes('/auth/token/') || req.url.includes('/auth/register/') || 
        req.url.includes('/auth/forgot-password/') || req.url.includes('/auth/reset-password/')) {
      return next.handle(req);
    }

    console.log('DEBUG: Interceptor - URL:', req.url);
    console.log('DEBUG: Interceptor - Token exists:', !!this.auth.tokenAccess());

    // Ajouter le token d'accès aux requêtes API
    const token = this.auth.tokenAccess();
    if (token) {
      const authReq = req.clone({
        headers: req.headers.set('Authorization', `Bearer ${token}`)
      });
      return next.handle(authReq).pipe(
        catchError((error) => {
          console.log('DEBUG: Interceptor - Error:', error);
          console.log('DEBUG: Interceptor - Status:', error.status);
          
          // Si erreur 401, essayer de rafraîchir le token
          if (error.status === 401) {
            console.log('DEBUG: 401 detected, attempting token refresh...');
            return this.auth.rafraichirAccessToken().pipe(
              switchMap((newTokens) => {
                console.log('DEBUG: Token refresh successful');
                if (newTokens && newTokens.access) {
                  const retryReq = req.clone({
                    headers: req.headers.set('Authorization', `Bearer ${newTokens.access}`)
                  });
                  return next.handle(retryReq);
                } else {
                  console.log('DEBUG: Token refresh failed, redirecting to login');
                  // Rediriger vers la page de connexion si le rafraîchissement échoue
                  this.auth.deconnexion();
                  window.location.href = '/connexion';
                  return throwError(() => new Error('Session expired'));
                }
              }),
              catchError((refreshError) => {
                console.log('DEBUG: Token refresh failed:', refreshError);
                this.auth.deconnexion();
                window.location.href = '/connexion';
                return throwError(() => new Error('Session expired'));
              })
            );
          }
          
          return throwError(() => error);
        })
      );
    }

    console.log('DEBUG: No token available, proceeding without auth header');
    return next.handle(req);
  }
}
