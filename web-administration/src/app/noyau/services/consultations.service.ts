import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, BehaviorSubject, of } from 'rxjs';
import { catchError, map, tap, shareReplay } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

export interface Consultation {
  id: number;
  patient: number;
  patient_prenom: string;
  patient_nom: string;
  dossier: number;
  rendez_vous?: number;
  praticien?: number;
  date: string;
  motif: string;
  observations: string;
  diagnostic: string;
  notes: string;
  actes: ActeRealise[];
  schema_dentaire?: SchemaDentaire;
  photos: PhotoClinique[];
  cree_le: string;
  modifie_le: string;
}

export interface ActeRealise {
  id: number;
  consultation: number;
  libelle: string;
  description: string;
  dent: string;
  cree_le: string;
}

export interface SchemaDentaire {
  id: number;
  consultation: number;
  donnees: any;
  cree_le: string;
  modifie_le: string;
}

export interface PhotoClinique {
  id: number;
  consultation: number;
  fichier: string;
  type_photo: 'pre_op' | 'post_op' | 'autre';
  commentaire: string;
  cree_le: string;
}

export interface ConsultationCreate {
  patient: number;
  dossier?: number;
  rendez_vous?: number;
  praticien?: number;
  date: string;
  motif: string;
  observations: string;
  diagnostic: string;
  notes: string;
}

export interface ConsultationUpdate {
  patient?: number;
  dossier?: number;
  rendez_vous?: number;
  praticien?: number;
  date?: string;
  motif?: string;
  observations?: string;
  diagnostic?: string;
  notes?: string;
}

@Injectable({
  providedIn: 'root'
})
export class ConsultationsService {
  private readonly apiUrl = `${environment.apiBaseUrl}/consultations/`;
  private readonly actesUrl = `${environment.apiBaseUrl}/actes`;
  private readonly schemasUrl = `${environment.apiBaseUrl}/schemas-dentaires`;
  private readonly photosUrl = `${environment.apiBaseUrl}/photos-cliniques`;

  // Cache pour les consultations
  private consultationsCache = new BehaviorSubject<Consultation[]>([]);
  public consultations$ = this.consultationsCache.asObservable();

  constructor(private http: HttpClient) {}

  // CRUD Consultations
  getConsultations(params?: {
    patient?: number;
    praticien?: number;
    date_debut?: string;
    date_fin?: string;
    page?: number;
    page_size?: number;
  }): Observable<Consultation[]> {
    let httpParams = new HttpParams();
    
    if (params?.patient) httpParams = httpParams.set('patient', params.patient);
    if (params?.praticien) httpParams = httpParams.set('praticien', params.praticien);
    if (params?.date_debut) httpParams = httpParams.set('date_debut', params.date_debut);
    if (params?.date_fin) httpParams = httpParams.set('date_fin', params.date_fin);
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.page_size) httpParams = httpParams.set('page_size', params.page_size);

    return this.http.get<Consultation[] | { results: Consultation[] }>(this.apiUrl, { params: httpParams }).pipe(
      map((response) => (Array.isArray(response) ? response : response.results ?? [])),
      tap(consultations => this.consultationsCache.next(consultations)),
      shareReplay(1),
      catchError(this.handleError<Consultation[]>('getConsultations', []))
    );
  }

  getConsultation(id: number): Observable<Consultation> {
    return this.http.get<Consultation>(`${this.apiUrl}${id}/`).pipe(
      catchError(this.handleError<Consultation>(`getConsultation id=${id}`))
    );
  }

  createConsultation(consultation: ConsultationCreate): Observable<Consultation> {
    return this.http.post<Consultation>(this.apiUrl, consultation).pipe(
      tap(newConsultation => {
        const current = this.consultationsCache.value;
        this.consultationsCache.next([...current, newConsultation]);
      }),
    );
  }

  updateConsultation(id: number, consultation: ConsultationUpdate): Observable<Consultation> {
    return this.http.put<Consultation>(`${this.apiUrl}${id}/`, consultation).pipe(
      tap(updatedConsultation => {
        const current = this.consultationsCache.value;
        const index = current.findIndex(c => c.id === id);
        if (index !== -1) {
          current[index] = updatedConsultation;
          this.consultationsCache.next([...current]);
        }
      }),
    );
  }

  deleteConsultation(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}${id}/`).pipe(
      tap(() => {
        const current = this.consultationsCache.value;
        this.consultationsCache.next(current.filter(c => c.id !== id));
      }),
    );
  }

  // Actes Réalisés
  getActesConsultation(consultationId: number): Observable<ActeRealise[]> {
    return this.http.get<ActeRealise[]>(`${this.actesUrl}/?consultation=${consultationId}`).pipe(
      catchError(this.handleError<ActeRealise[]>(`getActesConsultation consultationId=${consultationId}`, []))
    );
  }

  createActe(acte: Omit<ActeRealise, 'id' | 'cree_le'>): Observable<ActeRealise> {
    return this.http.post<ActeRealise>(this.actesUrl, acte).pipe(
      catchError(this.handleError<ActeRealise>('createActe'))
    );
  }

  updateActe(id: number, acte: Partial<ActeRealise>): Observable<ActeRealise> {
    return this.http.put<ActeRealise>(`${this.actesUrl}${id}/`, acte).pipe(
      catchError(this.handleError<ActeRealise>(`updateActe id=${id}`))
    );
  }

  deleteActe(id: number): Observable<void> {
    return this.http.delete<void>(`${this.actesUrl}${id}/`).pipe(
      catchError(this.handleError<void>(`deleteActe id=${id}`))
    );
  }

  // Schéma Dentaire
  getSchemaDentaire(consultationId: number): Observable<SchemaDentaire> {
    return this.http.get<SchemaDentaire>(`${this.schemasUrl}/?consultation=${consultationId}`).pipe(
      catchError(this.handleError<SchemaDentaire>(`getSchemaDentaire consultationId=${consultationId}`))
    );
  }

  createOrUpdateSchemaDentaire(schema: Omit<SchemaDentaire, 'id' | 'cree_le' | 'modifie_le'>): Observable<SchemaDentaire> {
    return this.http.post<SchemaDentaire>(this.schemasUrl, schema).pipe(
      catchError(this.handleError<SchemaDentaire>('createOrUpdateSchemaDentaire'))
    );
  }

  // Photos Cliniques
  getPhotosConsultation(consultationId: number): Observable<PhotoClinique[]> {
    return this.http.get<PhotoClinique[]>(`${this.photosUrl}/?consultation=${consultationId}`).pipe(
      catchError(this.handleError<PhotoClinique[]>(`getPhotosConsultation consultationId=${consultationId}`, []))
    );
  }

  uploadPhoto(consultationId: number, file: File, typePhoto: 'pre_op' | 'post_op' | 'autre', commentaire?: string): Observable<PhotoClinique> {
    const formData = new FormData();
    formData.append('consultation', consultationId.toString());
    formData.append('fichier', file);
    formData.append('type_photo', typePhoto);
    if (commentaire) {
      formData.append('commentaire', commentaire);
    }

    return this.http.post<PhotoClinique>(this.photosUrl, formData).pipe(
      catchError(this.handleError<PhotoClinique>('uploadPhoto'))
    );
  }

  deletePhoto(id: number): Observable<void> {
    return this.http.delete<void>(`${this.photosUrl}${id}/`).pipe(
      catchError(this.handleError<void>(`deletePhoto id=${id}`))
    );
  }

  // Statistiques
  getStatistiques(): Observable<{
    total_consultations: number;
    consultations_mois: number;
    consultations_semaine: number;
    top_patients: Array<{ patient: string; count: number }>;
    top_actes: Array<{ acte: string; count: number }>;
  }> {
    return this.http.get<any>(`${environment.apiBaseUrl}/statistiques/vue-generale/`).pipe(
      catchError(this.handleError<any>('getStatistiques', {
        total_consultations: 0,
        consultations_mois: 0,
        consultations_semaine: 0,
        top_patients: [],
        top_actes: []
      }))
    );
  }

  // Recherche
  rechercherConsultations(query: string): Observable<Consultation[]> {
    const params = new HttpParams().set('search', query);
    return this.http.get<Consultation[] | { results: Consultation[] }>(this.apiUrl, { params }).pipe(
      map((response) => (Array.isArray(response) ? response : response.results ?? [])),
      catchError(this.handleError<Consultation[]>('rechercherConsultations', []))
    );
  }

  /** Export CSV via l'action backend /consultations/export/ */
  exporterCsv(filters?: Record<string, unknown>): Observable<Blob> {
    let params = new HttpParams();
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== '') {
          params = params.set(key, String(value));
        }
      });
    }
    return this.http.get(`${this.apiUrl}export/`, { params, responseType: 'blob' });
  }

  // Export
  exporterConsultations(format: 'csv' | 'excel' | 'pdf', filters?: any): Observable<Blob> {
    let params = new HttpParams().set('format', format);
    
    if (filters) {
      Object.keys(filters).forEach(key => {
        if (filters[key] !== undefined && filters[key] !== null) {
          params = params.set(key, filters[key]);
        }
      });
    }

    return this.http.get(`${this.apiUrl}export/`, {
      params,
      responseType: 'blob',
    }).pipe(
      catchError(this.handleError<Blob>('exporterConsultations'))
    );
  }

  
  // Gestion des erreurs
  private handleError<T>(operation = 'operation', result?: T) {
    return (error: any): Observable<T> => {
      console.error(`${operation} failed:`, error);
      
      // Vous pouvez ajouter une notification d'erreur ici
      // this.notificationService.error(`${operation} a échoué`);
      
      return of(result as T);
    };
  }

  // Rafraîchir le cache
  refreshCache(): void {
    this.consultationsCache.next([]);
  }

  // Vider le cache
  clearCache(): void {
    this.consultationsCache.next([]);
  }
}
