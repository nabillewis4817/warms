import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, of, BehaviorSubject } from 'rxjs';
import { catchError, tap, shareReplay } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

export interface RendezVous {
  id?: number;
  patient: number;
  patient_prenom?: string;
  patient_nom?: string;
  praticien: number;
  praticien_prenom?: string;
  praticien_nom?: string;
  date: string;
  heure_debut: string;
  heure_fin: string;
  motif?: string;
  statut: 'planifie' | 'confirme' | 'en_cours' | 'termine' | 'annule';
  notes?: string;
  cree_le?: string;
  modifie_le?: string;
}

export interface CreateRendezVous {
  patient: number;
  praticien: number;
  date: string;
  heure_debut: string;
  heure_fin: string;
  motif?: string;
  statut?: 'planifie' | 'confirme';
  notes?: string;
}

export interface UpdateRendezVous {
  patient?: number;
  praticien?: number;
  date?: string;
  heure_debut?: string;
  heure_fin?: string;
  motif?: string;
  statut?: 'planifie' | 'confirme' | 'en_cours' | 'termine' | 'annule';
  notes?: string;
}

@Injectable({
  providedIn: 'root'
})
export class RendezVousService {
  private readonly baseUrl = `${environment.apiBaseUrl}/rendez-vous`;
  private readonly apiUrl = `${environment.apiBaseUrl}/rendez-vous/rendez-vous`;

  // Cache pour les rendez-vous
  private rendezVousCache = new BehaviorSubject<RendezVous[]>([]);
  public rendezVous$ = this.rendezVousCache.asObservable();

  constructor(private http: HttpClient) {}

  // CRUD Rendez-vous
  getRendezVous(params?: {
    patient?: number;
    praticien?: number;
    date_debut?: string;
    date_fin?: string;
    statut?: string;
    page?: number;
    page_size?: number;
  }): Observable<RendezVous[]> {
    let httpParams = new HttpParams();
    
    if (params?.patient) httpParams = httpParams.set('patient', params.patient);
    if (params?.praticien) httpParams = httpParams.set('praticien', params.praticien);
    if (params?.date_debut) httpParams = httpParams.set('date_debut', params.date_debut);
    if (params?.date_fin) httpParams = httpParams.set('date_fin', params.date_fin);
    if (params?.statut) httpParams = httpParams.set('statut', params.statut);
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.page_size) httpParams = httpParams.set('page_size', params.page_size);

    console.log('🔍 DEBUG - RendezVous URL appelée:', this.apiUrl);
    console.log('🔍 DEBUG - RendezVous Params:', httpParams.toString());

    return this.http.get<RendezVous[]>(this.apiUrl, { params: httpParams }).pipe(
      tap(rendezVous => this.rendezVousCache.next(rendezVous)),
      shareReplay(1),
      catchError(this.handleError<RendezVous[]>('getRendezVous', []))
    );
  }

  getRendezVousById(id: number): Observable<RendezVous> {
    return this.http.get<RendezVous>(`${this.apiUrl}${id}/`).pipe(
      catchError(this.handleError<RendezVous>(`getRendezVous id=${id}`))
    );
  }

  createRendezVous(rendezVous: CreateRendezVous): Observable<RendezVous> {
    return this.http.post<RendezVous>(this.apiUrl, rendezVous).pipe(
      tap(newRendezVous => {
        const current = this.rendezVousCache.value;
        this.rendezVousCache.next([...current, newRendezVous]);
      }),
      catchError(this.handleError<RendezVous>('createRendezVous'))
    );
  }

  updateRendezVous(id: number, rendezVous: UpdateRendezVous): Observable<RendezVous> {
    return this.http.put<RendezVous>(`${this.apiUrl}${id}/`, rendezVous).pipe(
      tap(updatedRendezVous => {
        const current = this.rendezVousCache.value;
        const index = current.findIndex(r => r.id === id);
        if (index !== -1) {
          current[index] = updatedRendezVous;
          this.rendezVousCache.next([...current]);
        }
      }),
      catchError(this.handleError<RendezVous>('updateRendezVous'))
    );
  }

  deleteRendezVous(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}${id}/`).pipe(
      tap(() => {
        const current = this.rendezVousCache.value;
        this.rendezVousCache.next(current.filter(r => r.id !== id));
      }),
      catchError(this.handleError<void>('deleteRendezVous'))
    );
  }

  // Export
  exporterRendezVous(format: 'csv' | 'excel' | 'pdf', filters?: any): Observable<Blob> {
    let params = new HttpParams().set('format', format);
    
    if (filters) {
      Object.keys(filters).forEach(key => {
        if (filters[key] !== undefined && filters[key] !== null) {
          params = params.set(key, filters[key]);
        }
      });
    }

    console.log('🔍 DEBUG - Export RendezVous URL appelée:', `${this.apiUrl}export/`);
    console.log('🔍 DEBUG - Export RendezVous Params:', params.toString());

    return this.http.get(`${this.apiUrl}export/`, { 
      params, 
      responseType: 'blob' 
    }).pipe(
      catchError(this.handleError<Blob>('exporterRendezVous'))
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
    this.rendezVousCache.next([]);
  }

  // Vider le cache
  clearCache(): void {
    this.rendezVousCache.next([]);
  }

  // Obtenir les rendez-vous du jour
  getRendezVousDuJour(): Observable<RendezVous[]> {
    const today = new Date().toISOString().split('T')[0];
    return this.getRendezVous({
      date_debut: today,
      date_fin: today
    });
  }

  // Obtenir les rendez-vous à venir
  getRendezVousAVenir(): Observable<RendezVous[]> {
    const today = new Date().toISOString().split('T')[0];
    return this.getRendezVous({
      date_debut: today,
      statut: 'planifie'
    });
  }

  // Confirmer un rendez-vous
  confirmerRendezVous(id: number): Observable<RendezVous> {
    return this.updateRendezVous(id, { statut: 'confirme' });
  }

  // Annuler un rendez-vous
  annulerRendezVous(id: number): Observable<RendezVous> {
    return this.updateRendezVous(id, { statut: 'annule' });
  }

  // Marquer comme terminé
  terminerRendezVous(id: number): Observable<RendezVous> {
    return this.updateRendezVous(id, { statut: 'termine' });
  }
}
