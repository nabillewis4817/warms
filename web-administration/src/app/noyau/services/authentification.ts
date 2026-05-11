import { HttpClient } from '@angular/common/http';
import { Injectable, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface JetonsAuth {
  access: string;
  refresh: string;
}

export interface RegisterPayload {
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  telephone?: string;
  role: 'chirurgien_dentiste' | 'secretaire' | 'infirmiere' | 'patient';
  password: string;
}

export interface UtilisateurConnecte {
  id: number;
  username: string;
  role: string;
  prenom: string;
  nom: string;
  email: string;
}

@Injectable({
  providedIn: 'root',
})
export class Authentification {
  private readonly baseUrl = `${environment.apiBaseUrl}/personnel`;
  readonly utilisateur = signal<UtilisateurConnecte | null>(null);

  constructor(private readonly http: HttpClient) {}

  connexion(username: string, password: string): Observable<JetonsAuth> {
    return this.http
      .post<JetonsAuth>(`${this.baseUrl}/auth/token/`, { username, password })
      .pipe(
        tap((jetons) => {
          localStorage.setItem('warms_access', jetons.access);
          localStorage.setItem('warms_refresh', jetons.refresh);
        })
      );
  }

  chargerProfil(): Observable<UtilisateurConnecte> {
    return this.http.get<UtilisateurConnecte>(`${this.baseUrl}/me/`).pipe(
      tap((profil) => {
        this.utilisateur.set(profil);
        // Utilisé par certaines pages (ex: filtrage messagerie)
        localStorage.setItem('utilisateur', JSON.stringify(profil));
      })
    );
  }

  register(payload: RegisterPayload): Observable<{ id: number; username: string; role: string }> {
    return this.http.post<{ id: number; username: string; role: string }>(
      `${this.baseUrl}/auth/register/`,
      payload
    );
  }

  forgotPassword(email: string): Observable<{ detail: string; token?: string }> {
    return this.http.post<{ detail: string; token?: string }>(
      `${this.baseUrl}/auth/forgot-password/`,
      { email }
    );
  }

  resetPassword(token: string, nouveau_mot_de_passe: string): Observable<{ detail: string }> {
    return this.http.post<{ detail: string }>(`${this.baseUrl}/auth/reset-password/`, {
      token,
      nouveau_mot_de_passe,
    });
  }

  deconnexion(): void {
    localStorage.removeItem('warms_access');
    localStorage.removeItem('warms_refresh');
    localStorage.removeItem('utilisateur');
    this.utilisateur.set(null);
  }

  estConnecte(): boolean {
    return !!localStorage.getItem('warms_access');
  }

  tokenAccess(): string | null {
    return localStorage.getItem('warms_access');
  }

  tokenRefresh(): string | null {
    return localStorage.getItem('warms_refresh');
  }

  rafraichirAccessToken(): Observable<JetonsAuth | { access: string }> {
    const refresh = this.tokenRefresh();
    return this.http
      .post<JetonsAuth | { access: string }>(`${this.baseUrl}/auth/token/refresh/`, { refresh })
      .pipe(
        tap((res: any) => {
          if (res?.access) localStorage.setItem('warms_access', res.access);
          if (res?.refresh) localStorage.setItem('warms_refresh', res.refresh);
        })
      );
  }
}

// #EbaJioloLewis
