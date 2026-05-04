import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';

// Interface pour les statistiques du dashboard
export interface DashboardStats {
  consultations: {
    total: number;
    aujourdHui: number;
    semaine: number;
    mois: number;
    tendance: number;
  };
  rendezVous: {
    total: number;
    aujourdHui: number;
    semaine: number;
    mois: number;
    tendance: number;
    enAttente: number;
    confirms: number;
    annules: number;
  };
  appels: {
    total: number;
    aujourdHui: number;
    semaine: number;
    mois: number;
    tendance: number;
    repondus: number;
    nonRepondus: number;
    enAttente: number;
  };
  tauxAbsenteeisme: {
    global: number;
    mois: number;
    semaine: number;
    tendance: number;
    absences: number;
    presences: number;
  };
}

@Injectable({
  providedIn: 'root'
})
export class DashboardService {
  private readonly baseUrl = 'http://127.0.0.1:8000/api/v1';

  constructor(private readonly http: HttpClient) {}

  // Récupérer les statistiques du dashboard
  getDashboardStats(): Observable<DashboardStats> {
    return this.http.get<DashboardStats>(`${this.baseUrl}/personnel/dashboard/stats/`).pipe(
      catchError(error => {
        console.error('Erreur lors de la récupération des statistiques:', error);
        // Lancer une erreur pour que le composant puisse afficher une alerte
        throw new Error('Impossible de se connecter au serveur. Veuillez vérifier que le backend est en cours d\'exécution.');
      })
    );
  }

  // Récupérer les statistiques individuelles pour chaque card
  getConsultationsStats(): Observable<DashboardStats['consultations']> {
    return this.http.get<DashboardStats['consultations']>(`${this.baseUrl}/consultations/stats/`).pipe(
      catchError(error => {
        console.error('Erreur consultations stats:', error);
        return of(this.getTestStats().consultations);
      })
    );
  }

  getRendezVousStats(): Observable<DashboardStats['rendezVous']> {
    return this.http.get<DashboardStats['rendezVous']>(`${this.baseUrl}/rendez_vous/stats/`).pipe(
      catchError(error => {
        console.error('Erreur rendez-vous stats:', error);
        return of(this.getTestStats().rendezVous);
      })
    );
  }

  getAppelsStats(): Observable<DashboardStats['appels']> {
    return this.http.get<DashboardStats['appels']>(`${this.baseUrl}/journaux/stats/`).pipe(
      catchError(error => {
        console.error('Erreur appels stats:', error);
        return of(this.getTestStats().appels);
      })
    );
  }

  getTauxAbsenteeismeStats(): Observable<DashboardStats['tauxAbsenteeisme']> {
    return this.http.get<DashboardStats['tauxAbsenteeisme']>(`${this.baseUrl}/personnel/taux-absenteisme/stats/`).pipe(
      catchError(error => {
        console.error('Erreur taux absentéisme stats:', error);
        return of(this.getTestStats().tauxAbsenteeisme);
      })
    );
  }

  // Méthode pour obtenir des données de test réalistes
  private getTestStats(): DashboardStats {
    return {
      consultations: {
        total: 1247,
        aujourdHui: 23,
        semaine: 156,
        mois: 487,
        tendance: 12.5
      },
      rendezVous: {
        total: 892,
        aujourdHui: 18,
        semaine: 134,
        mois: 423,
        tendance: 8.3,
        enAttente: 5,
        confirms: 11,
        annules: 2
      },
      appels: {
        total: 2156,
        aujourdHui: 47,
        semaine: 312,
        mois: 892,
        tendance: -3.2,
        repondus: 38,
        nonRepondus: 5,
        enAttente: 4
      },
      tauxAbsenteeisme: {
        global: 8.7,
        mois: 9.2,
        semaine: 7.8,
        tendance: -1.5,
        absences: 87,
        presences: 913
      }
    };
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
  getTrendColor(tendance: number): string {
    if (tendance > 0) return '#10b981'; // vert
    if (tendance < 0) return '#ef4444'; // rouge
    return '#6b7280'; // gris
  }

  // Méthode pour obtenir l'icône de tendance
  getTrendIcon(tendance: number): string {
    if (tendance > 0) return 'bi-arrow-up-short';
    if (tendance < 0) return 'bi-arrow-down-short';
    return 'bi-dash';
  }
}
