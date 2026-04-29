import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
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

    // Ajouter le token d'accès aux requêtes API
    const token = this.auth.tokenAccess();
    if (token) {
      const authReq = req.clone({
        headers: req.headers.set('Authorization', `Bearer ${token}`)
      });
      return next.handle(authReq);
    }

    return next.handle(req);
  }
}
