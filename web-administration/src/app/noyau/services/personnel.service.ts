import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

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

export interface PersonnelFilters {
  recherche?: string;
  role?: string;
  service?: string;
  statut?: string;
}

@Injectable({
  providedIn: 'root'
})
export class PersonnelService {
  private readonly apiUrl = 'http://127.0.0.1:8000/api/v1/personnel';

  constructor(private http: HttpClient) {}

  // Obtenir tout le personnel avec filtres
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
    return this.http.get<Personnel[]>(`${this.apiUrl}${params}`);
  }

  // Créer un nouveau membre du personnel
  creerPersonnel(personnel: Partial<Personnel>): Observable<Personnel> {
    return this.http.post<Personnel>(this.apiUrl, personnel);
  }

  // Mettre à jour un membre du personnel
  mettreAJourPersonnel(id: number, personnel: Partial<Personnel>): Observable<Personnel> {
    return this.http.put<Personnel>(`${this.apiUrl}/${id}`, personnel);
  }

  // Supprimer un membre du personnel
  supprimerPersonnel(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }

  // Obtenir les rôles disponibles
  getRoles(): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/roles`);
  }

  // Obtenir les services disponibles
  getServices(): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/services`);
  }

  // Obtenir les spécialités disponibles
  getSpecialites(): Observable<string[]> {
    return this.http.get<string[]>(`${this.apiUrl}/specialites`);
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
}
