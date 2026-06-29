import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

// Interface pour les statistiques du dashboard.
// "tendance" est null quand il n'y a aucune donnée le mois précédent pour
// comparer (base fraîche) : distingue "pas encore d'historique" de
// "stable à 0%" (sinon la tendance restait bloquée à "0.0%" en permanence
// dès qu'il n'y avait pas de mois précédent, donnant l'impression que les
// chiffres du dashboard ne bougeaient jamais).
export interface DashboardStats {
  consultations: {
    total: number;
    aujourdHui: number;
    semaine: number;
    mois: number;
    tendance: number | null;
  };
  rendezVous: {
    total: number;
    aujourdHui: number;
    semaine: number;
    mois: number;
    tendance: number | null;
    enAttente: number;
    confirms: number;
    annules: number;
  };
  appels: {
    total: number;
    aujourdHui: number;
    semaine: number;
    mois: number;
    tendance: number | null;
    repondus: number;
    nonRepondus: number;
    enAttente: number;
  };
  tauxAbsenteeisme: {
    global: number;
    mois: number;
    semaine: number;
    tendance: number | null;
    absences: number;
    presences: number;
  };
}

@Injectable({
  providedIn: 'root'
})
export class DashboardService {
  private readonly baseUrl = environment.apiBaseUrl;

  constructor(private readonly http: HttpClient) {}

  // Récupérer les statistiques du dashboard
  getDashboardStats(): Observable<DashboardStats> {
    return this.http.get<DashboardStats>(`${this.baseUrl}/personnel/dashboard/stats/`).pipe(
      catchError(error => {
        console.error('Erreur lors de la récupération des statistiques:', error);
        return throwError(() => new Error('Impossible de se connecter au serveur. Veuillez vérifier que le backend est en cours d\'exécution.'));
      })
    );
  }

  // Méthode pour formater les nombres
  formatNumber(value: number): string {
    if (value >= 1000) {
      return (value / 1000).toFixed(1) + 'k';
    }
    return value.toString();
  }

  // Méthode pour formater les pourcentages
  formatPercentage(value: number): string {
    return value.toFixed(1) + '%';
  }

  // Méthode pour obtenir la couleur de tendance
  getTrendColor(tendance: number | null): string {
    if (tendance === null) return '#9ca3af'; // gris neutre : pas d'historique
    if (tendance > 0) return '#10b981'; // vert
    if (tendance < 0) return '#ef4444'; // rouge
    return '#6b7280'; // gris
  }

  // Méthode pour obtenir l'icône de tendance
  getTrendIcon(tendance: number | null): string {
    if (tendance === null) return 'bi-stars';
    if (tendance > 0) return 'bi-arrow-up-short';
    if (tendance < 0) return 'bi-arrow-down-short';
    return 'bi-dash';
  }
}
