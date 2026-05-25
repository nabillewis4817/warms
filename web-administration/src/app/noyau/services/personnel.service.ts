import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { map, Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface Personnel {
  id: number;
  prenom: string;
  nom: string;
  email: string;
  telephone: string;
  role: string;
  service?: string;
  specialite?: string;
  photo?: string;
  date_embauche?: string;
  statut: string;
  derniere_connexion?: string;
}

interface PersonnelApi {
  id: number;
  username: string;
  email: string;
  first_name?: string;
  last_name?: string;
  prenom?: string;
  nom?: string;
  nom_complet?: string;
  telephone: string;
  role: string;
  is_active: boolean;
  service?: string;
  specialite?: string;
  date_embauche?: string;
  statut?: string;
  photo?: string;
  photo_profil?: string;
  langue_interface?: string;
  mode_sombre?: boolean;
  date_joined?: string;
  last_login?: string;
}

export interface PersonnelFilters {
  recherche?: string;
  role?: string;
  service?: string;
  statut?: string;
}

export interface Role {
  id: string;
  nom: string;
  description: string;
}

export interface Service {
  id: number;
  nom: string;
  description: string;
}

export interface Specialite {
  id: number;
  nom: string;
  description: string;
}

@Injectable({
  providedIn: 'root'
})
export class PersonnelService {
  private readonly apiUrl = `${environment.apiBaseUrl}/personnel/personnel/`;

  constructor(private http: HttpClient) {}

  // Obtenir tout le personnel avec filtres
  obtenirDetail(id: number): Observable<Personnel> {
    return this.http.get<PersonnelApi>(`${this.apiUrl}${id}/`).pipe(
      map((item) => this.mapApiToPersonnel(item))
    );
  }

  getPersonnel(filters?: PersonnelFilters): Observable<Personnel[]> {
    let params = '';
    if (filters) {
      const queryParams = new URLSearchParams();
      Object.entries(filters).forEach(([key, value]) => {
        if (value) {
          queryParams.append(key, value);
        }
      });
      params = `?${queryParams.toString()}`;
    }
    return this.http.get<PersonnelApi[] | { results: PersonnelApi[] }>(`${this.apiUrl}${params}`).pipe(
      map((response) => {
        const items = Array.isArray(response) ? response : response.results ?? [];
        return items.map((item) => this.mapApiToPersonnel(item));
      })
    );
  }

  // Créer un nouveau membre du personnel
  creerPersonnel(personnel: Partial<Personnel>): Observable<Personnel> {
    const payload = this.mapPersonnelToApiPayload(personnel);
    return this.http.post<PersonnelApi>(this.apiUrl, payload).pipe(map((item) => this.mapApiToPersonnel(item)));
  }

  // Mettre à jour un membre du personnel
  mettreAJourPersonnel(id: number, personnel: Partial<Personnel>): Observable<Personnel> {
    const payload = this.mapPersonnelToApiPayload(personnel);
    return this.http.patch<PersonnelApi>(`${this.apiUrl}${id}/`, payload).pipe(map((item) => this.mapApiToPersonnel(item)));
  }

  // Supprimer un membre du personnel
  supprimerPersonnel(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}${id}/`);
  }

  // Charger les options depuis le backend
  getRoles(): Observable<Role[]> {
    return this.http.get<Role[]>(`${environment.apiBaseUrl}/personnel/roles/`);
  }

  getServices(): Observable<Service[]> {
    return this.http.get<Service[]>(`${environment.apiBaseUrl}/personnel/services/`);
  }

  getSpecialites(): Observable<Specialite[]> {
    return this.http.get<Specialite[]>(`${environment.apiBaseUrl}/personnel/specialites/`);
  }

  // Exporter le personnel
  exporterPersonnel(filters?: PersonnelFilters): Observable<Blob> {
    let params = '';
    if (filters) {
      const queryParams = new URLSearchParams();
      Object.entries(filters).forEach(([key, value]) => {
        if (value) {
          queryParams.append(key, value);
        }
      });
      params = `?${queryParams.toString()}`;
    }
    return this.http.get(`${this.apiUrl}/exporter${params}`, { responseType: 'blob' });
  }

  // Obtenir les statistiques du personnel
  getStatistiques(): Observable<any> {
    return this.http.get(`${this.apiUrl}/statistiques`);
  }

  private mapApiToPersonnel(item: PersonnelApi): Personnel {
    let prenom = (item.first_name ?? item.prenom ?? '').trim();
    let nom = (item.last_name ?? item.nom ?? '').trim();
    if (!prenom && !nom && item.nom_complet) {
      const parts = item.nom_complet.trim().split(/\s+/);
      prenom = parts[0] ?? '';
      nom = parts.slice(1).join(' ');
    }
    const statut = item.statut ?? (item.is_active === false ? 'inactif' : 'actif');
    return {
      id: item.id,
      prenom,
      nom,
      email: item.email ?? '',
      telephone: item.telephone ?? '',
      role: item.role ?? '',
      service: item.service,
      specialite: item.specialite,
      photo: item.photo ?? item.photo_profil,
      date_embauche: item.date_embauche,
      statut,
      derniere_connexion: item.last_login,
    };
  }

  private mapPersonnelToApiPayload(personnel: Partial<Personnel>): Record<string, unknown> {
    const prenom = (personnel.prenom ?? '').trim();
    const nom = (personnel.nom ?? '').trim();
    const email = (personnel.email ?? '').trim();
    const fallbackUsername = [prenom, nom].filter(Boolean).join('.').toLowerCase() || email.split('@')[0] || `user${Date.now()}`;

    return {
      username: fallbackUsername,
      first_name: prenom,
      last_name: nom,
      email,
      telephone: personnel.telephone ?? '',
      role: personnel.role ?? 'infirmiere',
      // facultatif backend, mot de passe temporaire généré si vide
      password: '',
    };
  }
}
