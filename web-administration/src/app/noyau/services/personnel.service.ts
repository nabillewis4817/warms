import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { map, Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface PersonnelCompte {
  id: number;
  username: string;
  role: string;
  first_name: string;
  last_name: string;
  est_valide_par_chirurgien?: boolean;
  is_active: boolean;
}

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
  creerPersonnel(personnel: Partial<Personnel>, photo?: File | null): Observable<Personnel> {
    const prenom = (personnel.prenom ?? '').trim();
    const nom = (personnel.nom ?? '').trim();
    const email = (personnel.email ?? '').trim();
    const username = [prenom, nom].filter(Boolean).join('.').toLowerCase() || email.split('@')[0] || `user${Date.now()}`;

    const payload = this.construireFormData(personnel, photo);
    payload.append('username', username);
    payload.append('password', '');
    return this.http.post<PersonnelApi>(this.apiUrl, payload).pipe(map((item) => this.mapApiToPersonnel(item)));
  }

  // Mettre à jour un membre du personnel
  mettreAJourPersonnel(id: number, personnel: Partial<Personnel>, photo?: File | null): Observable<Personnel> {
    const payload = this.construireFormData(personnel, photo);
    return this.http.patch<PersonnelApi>(`${this.apiUrl}${id}/`, payload).pipe(map((item) => this.mapApiToPersonnel(item)));
  }

  // Changer uniquement le statut RH (action rapide)
  changerStatut(id: number, statut: string): Observable<Personnel> {
    const fd = new FormData();
    fd.append('statut', statut);
    return this.http.patch<PersonnelApi>(`${this.apiUrl}${id}/`, fd).pipe(map((item) => this.mapApiToPersonnel(item)));
  }

  // Supprimer un membre du personnel
  supprimerPersonnel(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}${id}/`);
  }

  supprimer(id: number): Observable<void> {
    return this.supprimerPersonnel(id);
  }

  // Méthodes compatibles avec l'ancienne interface (gestion-personnel, OCR, nouveau-patient)
  lister(): Observable<PersonnelCompte[]> {
    return this.http.get<PersonnelCompte[]>(this.apiUrl);
  }

  creer(payload: any, photo?: File | null): Observable<PersonnelCompte> {
    if (!photo) {
      return this.http.post<PersonnelCompte>(this.apiUrl, payload);
    }
    const formData = new FormData();
    Object.entries(payload as Record<string, unknown>).forEach(([cle, valeur]) => {
      if (valeur !== undefined && valeur !== null && valeur !== '') {
        formData.append(cle, String(valeur));
      }
    });
    formData.append('photo_profil', photo, photo.name);
    return this.http.post<PersonnelCompte>(this.apiUrl, formData);
  }

  valider(id: number): Observable<PersonnelCompte> {
    return this.http.post<PersonnelCompte>(`${this.apiUrl}${id}/valider/`, {});
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

  private construireFormData(personnel: Partial<Personnel>, photo?: File | null): FormData {
    const fd = new FormData();
    fd.append('first_name', (personnel.prenom ?? '').trim());
    fd.append('last_name', (personnel.nom ?? '').trim());
    fd.append('email', (personnel.email ?? '').trim());
    fd.append('telephone', personnel.telephone ?? '');
    fd.append('role', personnel.role ?? 'infirmiere');
    fd.append('service', personnel.service ?? '');
    fd.append('specialite', personnel.specialite ?? '');
    if (personnel.date_embauche) fd.append('date_embauche', personnel.date_embauche);
    fd.append('statut', personnel.statut ?? 'actif');
    if (photo) fd.append('photo_profil', photo, photo.name);
    return fd;
  }
}
