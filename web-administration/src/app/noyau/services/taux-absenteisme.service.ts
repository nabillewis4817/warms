import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, of, BehaviorSubject } from 'rxjs';
import { catchError, tap, shareReplay } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

export interface TauxAbsenteisme {
  id?: number;
  periode: string;
  date_debut: string;
  date_fin: string;
  taux_global: number;
  effectif_total: number;
  effectif_absent: number;
  effectif_present: number;
  taux_justifie: number;
  taux_non_justifie: number;
  taux_retard: number;
  classe?: string;
  cree_le?: string;
  modifie_le?: string;
}

export interface StatistiqueAbsenteisme {
  periode: string;
  taux_global: number;
  tendance: 'hausse' | 'baisse' | 'stable';
  variation: number;
  effectif_total: number;
  effectif_absent: number;
  details_par_classe?: {
    classe: string;
    taux: number;
    effectif: number;
  }[];
}

export interface CreateTauxAbsenteisme {
  periode: string;
  date_debut: string;
  date_fin: string;
  classe?: string;
}

export interface UpdateTauxAbsenteisme {
  periode?: string;
  date_debut?: string;
  date_fin?: string;
  classe?: string;
}

@Injectable({
  providedIn: 'root'
})
export class TauxAbsenteismeService {
  private readonly baseUrl = `${environment.apiBaseUrl}/consultations`;
  private readonly apiUrl = `${environment.apiBaseUrl}/consultations/taux-absenteisme`;

  // Cache pour les taux d'absentéisme
  private tauxCache = new BehaviorSubject<TauxAbsenteisme[]>([]);
  public taux$ = this.tauxCache.asObservable();

  constructor(private http: HttpClient) {}

  // CRUD Taux d'absentéisme
  getTauxAbsenteisme(params?: {
    periode?: string;
    date_debut?: string;
    date_fin?: string;
    classe?: string;
    page?: number;
    page_size?: number;
  }): Observable<TauxAbsenteisme[]> {
    let httpParams = new HttpParams();
    
    if (params?.periode) httpParams = httpParams.set('periode', params.periode);
    if (params?.date_debut) httpParams = httpParams.set('date_debut', params.date_debut);
    if (params?.date_fin) httpParams = httpParams.set('date_fin', params.date_fin);
    if (params?.classe) httpParams = httpParams.set('classe', params.classe);
    if (params?.page) httpParams = httpParams.set('page', params.page);
    if (params?.page_size) httpParams = httpParams.set('page_size', params.page_size);

    console.log('🔍 DEBUG - TauxAbsenteisme URL appelée:', this.apiUrl);
    console.log('🔍 DEBUG - TauxAbsenteisme Params:', httpParams.toString());

    return this.http.get<TauxAbsenteisme[]>(this.apiUrl, { params: httpParams }).pipe(
      tap(taux => this.tauxCache.next(taux)),
      shareReplay(1),
      catchError(this.handleError<TauxAbsenteisme[]>('getTauxAbsenteisme', []))
    );
  }

  getTauxAbsenteismeById(id: number): Observable<TauxAbsenteisme> {
    return this.http.get<TauxAbsenteisme>(`${this.apiUrl}${id}/`).pipe(
      catchError(this.handleError<TauxAbsenteisme>(`getTauxAbsenteisme id=${id}`))
    );
  }

  createTauxAbsenteisme(taux: CreateTauxAbsenteisme): Observable<TauxAbsenteisme> {
    return this.http.post<TauxAbsenteisme>(this.apiUrl, taux).pipe(
      tap(newTaux => {
        const current = this.tauxCache.value;
        this.tauxCache.next([...current, newTaux]);
      }),
      catchError(this.handleError<TauxAbsenteisme>('createTauxAbsenteisme'))
    );
  }

  updateTauxAbsenteisme(id: number, taux: UpdateTauxAbsenteisme): Observable<TauxAbsenteisme> {
    return this.http.put<TauxAbsenteisme>(`${this.apiUrl}${id}/`, taux).pipe(
      tap(updatedTaux => {
        const current = this.tauxCache.value;
        const index = current.findIndex(t => t.id === id);
        if (index !== -1) {
          current[index] = updatedTaux;
          this.tauxCache.next([...current]);
        }
      }),
      catchError(this.handleError<TauxAbsenteisme>('updateTauxAbsenteisme'))
    );
  }

  deleteTauxAbsenteisme(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}${id}/`).pipe(
      tap(() => {
        const current = this.tauxCache.value;
        this.tauxCache.next(current.filter(t => t.id !== id));
      }),
      catchError(this.handleError<void>('deleteTauxAbsenteisme'))
    );
  }

  // Statistiques et analyses
  getStatistiquesGenerales(params?: {
    date_debut?: string;
    date_fin?: string;
    classe?: string;
  }): Observable<StatistiqueAbsenteisme[]> {
    let httpParams = new HttpParams();
    
    if (params?.date_debut) httpParams = httpParams.set('date_debut', params.date_debut);
    if (params?.date_fin) httpParams = httpParams.set('date_fin', params.date_fin);
    if (params?.classe) httpParams = httpParams.set('classe', params.classe);

    return this.http.get<StatistiqueAbsenteisme[]>(`${this.apiUrl}statistiques/`, { params: httpParams }).pipe(
      catchError(this.handleError<StatistiqueAbsenteisme[]>('getStatistiquesGenerales', []))
    );
  }

  getTauxMensuel(annee: number): Observable<TauxAbsenteisme[]> {
    return this.getTauxAbsenteisme({
      date_debut: `${annee}-01-01`,
      date_fin: `${annee}-12-31`
    });
  }

  getTauxActuel(): Observable<TauxAbsenteisme> {
    const today = new Date();
    const debutMois = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0];
    const finMois = new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString().split('T')[0];
    
    return this.http.get<TauxAbsenteisme>(`${this.apiUrl}actuel/`, {
      params: {
        date_debut: debutMois,
        date_fin: finMois
      }
    }).pipe(
      catchError(this.handleError<TauxAbsenteisme>('getTauxActuel'))
    );
  }

  getTendance(params?: {
    periode?: 'semaine' | 'mois' | 'trimestre' | 'annee';
    nombre_periodes?: number;
  }): Observable<any> {
    let httpParams = new HttpParams();
    
    if (params?.periode) httpParams = httpParams.set('periode', params.periode);
    if (params?.nombre_periodes) httpParams = httpParams.set('nombre_periodes', params.nombre_periodes);

    return this.http.get<any>(`${this.apiUrl}tendance/`, { params: httpParams }).pipe(
      catchError(this.handleError<any>('getTendance'))
    );
  }

  getComparaisonClasses(date_debut: string, date_fin: string): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}comparaison-classes/`, {
      params: { date_debut, date_fin }
    }).pipe(
      catchError(this.handleError<any>('getComparaisonClasses'))
    );
  }

  // Export
  exporterTaux(format: 'csv' | 'excel' | 'pdf', filters?: any): Observable<Blob> {
    let params = new HttpParams().set('format', format);
    
    if (filters) {
      Object.keys(filters).forEach(key => {
        if (filters[key] !== undefined && filters[key] !== null) {
          params = params.set(key, filters[key]);
        }
      });
    }

    console.log('🔍 DEBUG - Export TauxAbsenteisme URL appelée:', `${this.apiUrl}export/`);
    console.log('🔍 DEBUG - Export TauxAbsenteisme Params:', params.toString());

    return this.http.get(`${this.apiUrl}export/`, { 
      params, 
      responseType: 'blob' 
    }).pipe(
      catchError(this.handleError<Blob>('exporterTaux'))
    );
  }

  exporterStatistiques(format: 'csv' | 'excel' | 'pdf', params?: any): Observable<Blob> {
    let httpParams = new HttpParams().set('format', format);
    
    if (params) {
      Object.keys(params).forEach(key => {
        if (params[key] !== undefined && params[key] !== null) {
          httpParams = httpParams.set(key, params[key]);
        }
      });
    }

    return this.http.get(`${this.apiUrl}export-statistiques/`, { 
      params: httpParams, 
      responseType: 'blob' 
    }).pipe(
      catchError(this.handleError<Blob>('exporterStatistiques'))
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
    this.tauxCache.next([]);
  }

  // Vider le cache
  clearCache(): void {
    this.tauxCache.next([]);
  }

  // Méthodes utilitaires
  getTauxDuMois(): Observable<TauxAbsenteisme[]> {
    const today = new Date();
    const debutMois = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0];
    const finMois = new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString().split('T')[0];
    
    return this.getTauxAbsenteisme({
      date_debut: debutMois,
      date_fin: finMois
    });
  }

  getTauxDeLaSemaine(): Observable<TauxAbsenteisme[]> {
    const today = new Date();
    const debutSemaine = new Date(today.setDate(today.getDate() - today.getDay())).toISOString().split('T')[0];
    const finSemaine = new Date(today.setDate(today.getDate() - today.getDay() + 6)).toISOString().split('T')[0];
    
    return this.getTauxAbsenteisme({
      date_debut: debutSemaine,
      date_fin: finSemaine
    });
  }

  // Calculer le taux d'absentéisme pour une période donnée
  calculerTauxAbsenteisme(date_debut: string, date_fin: string, classe?: string): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}calculer/`, {
      date_debut,
      date_fin,
      classe
    }).pipe(
      catchError(this.handleError<any>('calculerTauxAbsenteisme'))
    );
  }

  // Générer un rapport d'absentéisme
  genererRapport(params: {
    date_debut: string;
    date_fin: string;
    format: 'pdf' | 'html';
    classe?: string;
    include_details?: boolean;
  }): Observable<Blob> {
    return this.http.post(`${this.apiUrl}rapport/`, params, {
      responseType: 'blob'
    }).pipe(
      catchError(this.handleError<Blob>('genererRapport'))
    );
  }
}
