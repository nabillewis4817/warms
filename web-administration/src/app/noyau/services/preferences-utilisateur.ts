import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface PreferencesNotifications {
  email?: boolean;
  sms?: boolean;
  push?: boolean;
  rappels_auto?: boolean;
}

export interface ProfilUtilisateur {
  id: number;
  username: string;
  email: string;
  prenom: string;
  nom: string;
  role: string;
  telephone: string;
  photo_profil: string | null;
  langue_interface: 'fr' | 'en';
  mode_sombre: boolean;
  preferences_notifications: PreferencesNotifications;
}

export interface PatchPreferencesPayload {
  first_name?: string;
  last_name?: string;
  email?: string;
  telephone?: string;
  langue_interface?: 'fr' | 'en';
  mode_sombre?: boolean;
  preferences_notifications?: PreferencesNotifications;
}

@Injectable({
  providedIn: 'root',
})
export class PreferencesUtilisateurService {
  private readonly baseUrl = `${environment.apiBaseUrl}/personnel`;

  constructor(private readonly http: HttpClient) {}

  obtenirMonProfil(): Observable<ProfilUtilisateur> {
    return this.http.get<ProfilUtilisateur>(`${this.baseUrl}/me/`);
  }

  mettreAJourPreferences(payload: PatchPreferencesPayload): Observable<Partial<ProfilUtilisateur>> {
    return this.http.patch<Partial<ProfilUtilisateur>>(`${this.baseUrl}/me/preferences/`, payload);
  }

  mettreAJourPreferencesMultipart(formData: FormData): Observable<Partial<ProfilUtilisateur>> {
    return this.http.patch<Partial<ProfilUtilisateur>>(`${this.baseUrl}/me/preferences/`, formData);
  }
}

// #EbaJioloLewis
