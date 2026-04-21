import { HttpClient } from '@angular/common/http';
import { Injectable, signal } from '@angular/core';
import { Observable, tap } from 'rxjs';

export interface JetonsAuth {
  access: string;
  refresh: string;
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
  private readonly baseUrl = 'http://127.0.0.1:8000/api/v1/personnel';
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
      tap((profil) => this.utilisateur.set(profil))
    );
  }

  deconnexion(): void {
    localStorage.removeItem('warms_access');
    localStorage.removeItem('warms_refresh');
    this.utilisateur.set(null);
  }

  estConnecte(): boolean {
    return !!localStorage.getItem('warms_access');
  }

  tokenAccess(): string | null {
    return localStorage.getItem('warms_access');
  }
}

// #EbaJioloLewis
