import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, BehaviorSubject, of } from 'rxjs';
import { catchError, map, tap } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

export type StatutPrescription = 'active' | 'terminee' | 'annulee';

export interface LignePrescription {
  id?: number;
  prescription?: number;
  medicament: string;
  posologie: string;
  duree: string;
  remarques: string;
}

export interface Prescription {
  id: number;
  patient: number;
  patient_prenom: string;
  patient_nom: string;
  dossier: string;
  consultation?: number | null;
  praticien?: number | null;
  praticien_nom: string;
  titre: string;
  note_praticien: string;
  conseils: string;
  recommandations: string;
  statut: StatutPrescription;
  lignes: LignePrescription[];
  cree_le: string;
  modifie_le: string;
}

export interface PrescriptionPayload {
  patient: number;
  dossier?: string | null;
  consultation?: number | null;
  praticien?: number | null;
  titre: string;
  note_praticien: string;
  conseils: string;
  recommandations: string;
  statut: StatutPrescription;
  lignes: LignePrescription[];
}

@Injectable({
  providedIn: 'root',
})
export class PrescriptionsService {
  private readonly apiUrl = `${environment.apiBaseUrl}/prescriptions/`;

  private prescriptionsCache = new BehaviorSubject<Prescription[]>([]);
  public prescriptions$ = this.prescriptionsCache.asObservable();

  constructor(private http: HttpClient) {}

  lister(params?: { patient?: number; statut?: StatutPrescription; search?: string }): Observable<Prescription[]> {
    let httpParams = new HttpParams();
    if (params?.patient) httpParams = httpParams.set('patient', params.patient);
    if (params?.statut) httpParams = httpParams.set('statut', params.statut);
    if (params?.search) httpParams = httpParams.set('search', params.search);

    return this.http.get<Prescription[] | { results: Prescription[] }>(this.apiUrl, { params: httpParams }).pipe(
      map((reponse) => (Array.isArray(reponse) ? reponse : reponse.results ?? [])),
      tap((prescriptions) => this.prescriptionsCache.next(prescriptions)),
      catchError(this.gererErreur<Prescription[]>('lister', []))
    );
  }

  historiquePatient(patientId: number): Observable<Prescription[]> {
    return this.http
      .get<Prescription[] | { results: Prescription[] }>(`${this.apiUrl}patient/${patientId}/historique/`)
      .pipe(
        map((reponse) => (Array.isArray(reponse) ? reponse : reponse.results ?? [])),
        catchError(this.gererErreur<Prescription[]>('historiquePatient', []))
      );
  }

  obtenir(id: number): Observable<Prescription> {
    return this.http
      .get<Prescription>(`${this.apiUrl}${id}/`)
      .pipe(catchError(this.gererErreur<Prescription>(`obtenir id=${id}`)));
  }

  // creer/modifier/supprimer ne passent volontairement pas par gererErreur :
  // cette dernière avale l'erreur HTTP et émet une valeur de repli comme si
  // l'appel avait réussi, ce qui faisait croire à l'UI qu'une prescription
  // était enregistrée alors qu'un 400 avait été renvoyé (rien n'était
  // réellement en base). Ces trois opérations doivent laisser l'erreur
  // remonter pour que le composant appelant affiche un vrai message d'échec.
  creer(payload: PrescriptionPayload): Observable<Prescription> {
    return this.http.post<Prescription>(this.apiUrl, payload).pipe(
      tap((nouvelle) => this.prescriptionsCache.next([nouvelle, ...this.prescriptionsCache.value]))
    );
  }

  modifier(id: number, payload: PrescriptionPayload): Observable<Prescription> {
    return this.http.put<Prescription>(`${this.apiUrl}${id}/`, payload).pipe(
      tap((maj) => {
        const courant = this.prescriptionsCache.value;
        const index = courant.findIndex((p) => p.id === id);
        if (index !== -1) {
          courant[index] = maj;
          this.prescriptionsCache.next([...courant]);
        }
      })
    );
  }

  supprimer(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}${id}/`).pipe(
      tap(() => this.prescriptionsCache.next(this.prescriptionsCache.value.filter((p) => p.id !== id)))
    );
  }

  // Le PDF exige une session connectée côté backend ; un simple
  // window.open(url) ou <a href> navigue sans passer par le jwtInterceptor
  // (qui n'agit que sur les requêtes HttpClient), donc sans l'en-tête
  // Authorization — la requête échouait toujours. On télécharge ici le
  // contenu en blob via HttpClient (auth incluse), puis l'appelant ouvre
  // l'URL d'objet obtenue.
  telechargerPdf(id: number): Observable<Blob> {
    return this.http.get(`${this.apiUrl}${id}/pdf/`, { responseType: 'blob' });
  }

  /** Envoie la signature dessinée (base64 PNG) et récupère le PDF signé prêt à imprimer. */
  signerPdf(id: number, signatureBase64: string): Observable<Blob> {
    return this.http.post(
      `${this.apiUrl}${id}/signer-pdf/`,
      { signature_base64: signatureBase64 },
      { responseType: 'blob' },
    );
  }

  private gererErreur<T>(operation = 'operation', resultat?: T) {
    return (erreur: any): Observable<T> => {
      console.error(`${operation} a échoué :`, erreur);
      return of(resultat as T);
    };
  }
}

// #EbaJioloLewis
