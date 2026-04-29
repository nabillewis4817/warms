import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable, interval } from 'rxjs';
import { map, startWith } from 'rxjs/operators';

/**
 * Service de gestion de la date et heure en temps réel
 * 
 * Ce service fournit une mise à jour automatique de la date et heure
 * avec différents formats pour s'adapter à l'interface utilisateur.
 * 
 * @author WARMS Team
 * @version 1.0.0
 */
@Injectable({
  providedIn: 'root'
})
export class DateTimeService {
  
  /** Intervalle de mise à jour en millisecondes (1 seconde) */
  private readonly UPDATE_INTERVAL = 1000;
  
  /** BehaviorSubject pour stocker la date/heure actuelle */
  private readonly _currentDateTime$ = new BehaviorSubject<Date>(new Date());
  
  /** Observable public de la date/heure */
  public readonly currentDateTime$: Observable<Date> = this._currentDateTime$.asObservable();
  
  /** Observable formaté pour l'affichage compact */
  public readonly formattedDateTime$: Observable<string> = this._currentDateTime$.pipe(
    map(date => this.formatDateTime(date))
  );
  
  /** Observable formaté pour l'affichage étendu */
  public readonly formattedDateExtended$: Observable<string> = this._currentDateTime$.pipe(
    map(date => this.formatDateExtended(date))
  );
  
  /** Observable pour l'heure seulement */
  public readonly timeOnly$: Observable<string> = this._currentDateTime$.pipe(
    map(date => this.formatTime(date))
  );
  
  /** Observable pour la date seulement */
  public readonly dateOnly$: Observable<string> = this._currentDateTime$.pipe(
    map(date => this.formatDate(date))
  );

  /** Intervalle de mise à jour */
  private updateInterval: any;

  constructor() {
    this.startDateTimeUpdates();
  }

  /**
   * Démarre les mises à jour automatiques de la date/heure
   */
  private startDateTimeUpdates(): void {
    // Mise à jour immédiate
    this.updateDateTime();
    
    // Configuration de l'intervalle de mise à jour
    this.updateInterval = interval(this.UPDATE_INTERVAL).subscribe(() => {
      this.updateDateTime();
    });
  }

  /**
   * Met à jour la date/heure actuelle
   */
  private updateDateTime(): void {
    this._currentDateTime$.next(new Date());
  }

  /**
   * Formate la date et heure pour un affichage compact
   * Format: "JJ/MM/AAAA HH:mm:ss"
   */
  private formatDateTime(date: Date): string {
    const day = date.getDate().toString().padStart(2, '0');
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const year = date.getFullYear();
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    
    return `${day}/${month}/${year} ${hours}:${minutes}:${seconds}`;
  }

  /**
   * Formate la date et heure pour un affichage étendu avec le nom du jour
   * Format: "Lundi 27 Avril 2026 - 10:47:32"
   */
  private formatDateExtended(date: Date): string {
    const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    const monthNames = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 
                       'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    
    const dayName = dayNames[date.getDay()];
    const day = date.getDate();
    const monthName = monthNames[date.getMonth()];
    const year = date.getFullYear();
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    
    return `${dayName} ${day} ${monthName} ${year} - ${hours}:${minutes}:${seconds}`;
  }

  /**
   * Formate uniquement l'heure
   * Format: "HH:mm:ss"
   */
  private formatTime(date: Date): string {
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    
    return `${hours}:${minutes}:${seconds}`;
  }

  /**
   * Formate uniquement la date
   * Format: "JJ/MM/AAAA"
   */
  private formatDate(date: Date): string {
    const day = date.getDate().toString().padStart(2, '0');
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const year = date.getFullYear();
    
    return `${day}/${month}/${year}`;
  }

  /**
   * Retourne le nom du jour actuel
   */
  public getCurrentDayName(): string {
    const dayNames = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    return dayNames[new Date().getDay()];
  }

  /**
   * Retourne une représentation relative du temps (ex: "Il y a 5 minutes")
   */
  public getRelativeTime(date: Date): string {
    const now = new Date();
    const diffInMs = now.getTime() - date.getTime();
    const diffInMinutes = Math.floor(diffInMs / 60000);
    const diffInHours = Math.floor(diffInMinutes / 60);
    const diffInDays = Math.floor(diffInHours / 24);

    if (diffInMinutes < 1) {
      return 'À l\'instant';
    } else if (diffInMinutes < 60) {
      return `Il y a ${diffInMinutes} minute${diffInMinutes > 1 ? 's' : ''}`;
    } else if (diffInHours < 24) {
      return `Il y a ${diffInHours} heure${diffInHours > 1 ? 's' : ''}`;
    } else if (diffInDays < 7) {
      return `Il y a ${diffInDays} jour${diffInDays > 1 ? 's' : ''}`;
    } else {
      return this.formatDate(date);
    }
  }

  /**
   * Vérifie si l'heure actuelle est dans la plage de travail (9h-18h)
   */
  public isWorkingHours(): boolean {
    const currentHour = new Date().getHours();
    return currentHour >= 9 && currentHour <= 18;
  }

  /**
   * Retourne un message contextuel basé sur l'heure
   */
  public getTimeBasedGreeting(): string {
    const currentHour = new Date().getHours();
    
    if (currentHour < 12) {
      return '☀️ Bonjour';
    } else if (currentHour < 18) {
      return '🌤️ Bon après-midi';
    } else {
      return '🌙 Bonsoir';
    }
  }

  /**
   * Détruit le service et nettoie les intervalles
   */
  public ngOnDestroy(): void {
    if (this.updateInterval) {
      this.updateInterval.unsubscribe();
    }
  }
}
