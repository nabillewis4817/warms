import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, of, BehaviorSubject } from 'rxjs';
import { catchError, tap, shareReplay } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

export interface Appel {
  id?: number;
  date: string;
  classe: string;
  heure: string;
  effectif_total: number;
  effectif_present: number;
  effectif_absent: number;
  statut: 'en_cours' | 'termine' | 'annule';
  notes?: string;
  cree_par?: number;
  cree_par_nom?: string;
  cree_le?: string;
  modifie_le?: string;
  absences?: Absence[];
}

export interface Absence {
  id?: number;
  appel: number;
  patient: number;
  patient_nom?: string;
  patient_prenom?: string;
  motif?: string;
  type_absence: 'justifiee' | 'non_justifiee' | 'retard';
  statut: 'absent' | 'present' | 'retard';
  notes?: string;
  cree_le?: string;
  modifie_le?: string;
}

export interface CreateAppel {
  date: string;
  classe: string;
  heure: string;
  effectif_total: number;
  notes?: string;
}

export interface CreateAbsence {
  appel: number;
  patient: number;
  motif?: string;
  type_absence: 'justifiee' | 'non_justifiee' | 'retard';
  statut: 'absent' | 'present' | 'retard';
  notes?: string;
}

export interface UpdateAppel {
  date?: string;
  classe?: string;
  heure?: string;
  effectif_total?: number;
  statut?: 'en_cours' | 'termine' | 'annule';
  notes?: string;
}

export interface UpdateAbsence {
  patient?: number;
  motif?: string;
  type_absence?: 'justifiee' | 'non_justifiee' | 'retard';
  statut?: 'absent' | 'present' | 'retard';
  notes?: string;
}

@Injectable({
  providedIn: 'root'
})
export class AppelsService {
  private readonly baseUrl = `${environment.apiBaseUrl}/consultations`;
  private readonly appelsUrl = `${environment.apiBaseUrl}/consultations/appels`;
  private readonly absencesUrl = `${environment.apiBaseUrl}/consultations/absences`;

  // Cache pour les appels
  private appelsCache = new BehaviorSubject<Appel[]>([]);
  public appels$ = this.appelsCache.asObservable();

  // Cache pour les absences
  private absencesCache = new BehaviorSubject<Absence[]>([]);
  public absences$ = this.absencesCache.asObservable();

  constructor(private http: HttpClient) {}

  // CRUD Appels
  getAppels(params?: {
    date?: string;
    classe?: string;
    statut?: string;
    page?: number;
    page_size?: number;
  }): Observable<Appel[]> {
    let httpParams = new HttpParams();
    
    if (params?.date) httpParams = httpParams.set('date', params.date);
    if (params?.classe) httpParams = httpParams.set('classe', params.classe);
    if (params?.statut) httpParams = httpParams.set('statut', params.statut);
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.page_size) httpParams = httpParams.set('page_size', params.page_size);

    console.log('🔍 DEBUG - Appels URL appelée:', this.appelsUrl);
    console.log('🔍 DEBUG - Appels Params:', httpParams.toString());

    return this.http.get<Appel[]>(this.appelsUrl, { params: httpParams }).pipe(
      tap(appels => this.appelsCache.next(appels)),
      shareReplay(1),
      catchError(this.handleError<Appel[]>('getAppels', []))
    );
  }

  getAppel(id: number): Observable<Appel> {
    return this.http.get<Appel>(`${this.appelsUrl}${id}/`).pipe(
      catchError(this.handleError<Appel>(`getAppel id=${id}`))
    );
  }

  createAppel(appel: CreateAppel): Observable<Appel> {
    return this.http.post<Appel>(this.appelsUrl, appel).pipe(
      tap(newAppel => {
        const current = this.appelsCache.value;
        this.appelsCache.next([...current, newAppel]);
      }),
      catchError(this.handleError<Appel>('createAppel'))
    );
  }

  updateAppel(id: number, appel: UpdateAppel): Observable<Appel> {
    return this.http.put<Appel>(`${this.appelsUrl}${id}/`, appel).pipe(
      tap(updatedAppel => {
        const current = this.appelsCache.value;
        const index = current.findIndex(a => a.id === id);
        if (index !== -1) {
          current[index] = updatedAppel;
          this.appelsCache.next([...current]);
        }
      }),
      catchError(this.handleError<Appel>('updateAppel'))
    );
  }

  deleteAppel(id: number): Observable<void> {
    return this.http.delete<void>(`${this.appelsUrl}${id}/`).pipe(
      tap(() => {
        const current = this.appelsCache.value;
        this.appelsCache.next(current.filter(a => a.id !== id));
      }),
      catchError(this.handleError<void>('deleteAppel'))
    );
  }

  // CRUD Absences
  getAbsences(params?: {
    appel?: number;
    patient?: number;
    type_absence?: string;
    statut?: string;
    date?: string;
    page?: number;
    page_size?: number;
  }): Observable<Absence[]> {
    let httpParams = new HttpParams();
    
    if (params?.appel) httpParams = httpParams.set('appel', params.appel);
    if (params?.patient) httpParams = httpParams.set('patient', params.patient);
    if (params?.type_absence) httpParams = httpParams.set('type_absence', params.type_absence);
    if (params?.statut) httpParams = httpParams.set('statut', params.statut);
    if (params?.date) httpParams = httpParams.set('date', params.date);
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.page_size) httpParams = httpParams.set('page_size', params.page_size);

    console.log('🔍 DEBUG - Absences URL appelée:', this.absencesUrl);
    console.log('🔍 DEBUG - Absences Params:', httpParams.toString());

    return this.http.get<Absence[]>(this.absencesUrl, { params: httpParams }).pipe(
      tap(absences => this.absencesCache.next(absences)),
      shareReplay(1),
      catchError(this.handleError<Absence[]>('getAbsences', []))
    );
  }

  getAbsence(id: number): Observable<Absence> {
    return this.http.get<Absence>(`${this.absencesUrl}${id}/`).pipe(
      catchError(this.handleError<Absence>(`getAbsence id=${id}`))
    );
  }

  createAbsence(absence: CreateAbsence): Observable<Absence> {
    return this.http.post<Absence>(this.absencesUrl, absence).pipe(
      tap(newAbsence => {
        const current = this.absencesCache.value;
        this.absencesCache.next([...current, newAbsence]);
      }),
      catchError(this.handleError<Absence>('createAbsence'))
    );
  }

  updateAbsence(id: number, absence: UpdateAbsence): Observable<Absence> {
    return this.http.put<Absence>(`${this.absencesUrl}${id}/`, absence).pipe(
      tap(updatedAbsence => {
        const current = this.absencesCache.value;
        const index = current.findIndex(a => a.id === id);
        if (index !== -1) {
          current[index] = updatedAbsence;
          this.absencesCache.next([...current]);
        }
      }),
      catchError(this.handleError<Absence>('updateAbsence'))
    );
  }

  deleteAbsence(id: number): Observable<void> {
    return this.http.delete<void>(`${this.absencesUrl}${id}/`).pipe(
      tap(() => {
        const current = this.absencesCache.value;
        this.absencesCache.next(current.filter(a => a.id !== id));
      }),
      catchError(this.handleError<void>('deleteAbsence'))
    );
  }

  // Export
  exporterAppels(format: 'csv' | 'excel' | 'pdf', filters?: any): Observable<Blob> {
    let params = new HttpParams().set('format', format);
    
    if (filters) {
      Object.keys(filters).forEach(key => {
        if (filters[key] !== undefined && filters[key] !== null) {
          params = params.set(key, filters[key]);
        }
      });
    }

    return this.http.get(`${this.appelsUrl}export/`, { 
      params, 
      responseType: 'blob' 
    }).pipe(
      catchError(this.handleError<Blob>('exporterAppels'))
    );
  }

  exporterAbsences(format: 'csv' | 'excel' | 'pdf', filters?: any): Observable<Blob> {
    let params = new HttpParams().set('format', format);
    
    if (filters) {
      Object.keys(filters).forEach(key => {
        if (filters[key] !== undefined && filters[key] !== null) {
          params = params.set(key, filters[key]);
        }
      });
    }

    return this.http.get(`${this.absencesUrl}export/`, { 
      params, 
      responseType: 'blob' 
    }).pipe(
      catchError(this.handleError<Blob>('exporterAbsences'))
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
    this.appelsCache.next([]);
    this.absencesCache.next([]);
  }

  // Vider le cache
  clearCache(): void {
    this.appelsCache.next([]);
    this.absencesCache.next([]);
  }

  // Obtenir les appels du jour
  getAppelsDuJour(): Observable<Appel[]> {
    const today = new Date().toISOString().split('T')[0];
    return this.getAppels({ date: today });
  }

  // Obtenir les absences du jour
  getAbsencesDuJour(): Observable<Absence[]> {
    const today = new Date().toISOString().split('T')[0];
    return this.getAbsences({ date: today });
  }

  // Terminer un appel
  terminerAppel(id: number): Observable<Appel> {
    return this.updateAppel(id, { statut: 'termine' });
  }

  // Marquer un patient comme présent
  marquerPresent(id: number): Observable<Absence> {
    return this.updateAbsence(id, { statut: 'present' });
  }

  // Marquer un patient comme absent
  marquerAbsent(id: number, motif?: string): Observable<Absence> {
    return this.updateAbsence(id, { statut: 'absent', motif });
  }

  // Justifier une absence
  justifierAbsence(id: number, motif: string): Observable<Absence> {
    return this.updateAbsence(id, { 
      type_absence: 'justifiee', 
      motif,
      statut: 'absent'
    });
  }

  // Statistiques
  getStatistiquesAbsences(date?: string): Observable<any> {
    let httpParams = new HttpParams();
    if (date) {
      httpParams = httpParams.set('date', date);
    }
    return this.http.get(`${this.appelsUrl}statistiques/`, { params: httpParams }).pipe(
      catchError(this.handleError<any>('getStatistiquesAbsences'))
    );
  }
}
