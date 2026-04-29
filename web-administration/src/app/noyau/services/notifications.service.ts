import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';

export interface BadgeNotification {
  message: number;
  critique: number;
  rappel: number;
  total: number;
}

export interface NotificationSound {
  enabled: boolean;
  volume: number;
  type: 'default' | 'chime' | 'bell' | 'alert';
}

@Injectable({
  providedIn: 'root'
})
export class NotificationsService {
  private badgesSubject = new BehaviorSubject<BadgeNotification>({
    message: 0,
    critique: 0,
    rappel: 0,
    total: 0
  });

  private soundSettings = new BehaviorSubject<NotificationSound>({
    enabled: true,
    volume: 0.7,
    type: 'chime'
  });

  private audioContext: AudioContext | null = null;
  private notificationSound: HTMLAudioElement | null = null;

  constructor() {
    this.initializeAudio();
    this.loadSettings();
  }

  // Observable pour les badges
  get badges$(): Observable<BadgeNotification> {
    return this.badgesSubject.asObservable();
  }

  // Observable pour les paramètres sonores
  get soundSettings$(): Observable<NotificationSound> {
    return this.soundSettings.asObservable();
  }

  // Mettre à jour les badges
  updateBadges(badges: Partial<BadgeNotification>): void {
    const current = this.badgesSubject.value;
    const updated = {
      ...current,
      ...badges,
      total: (badges.message || 0) + (badges.critique || 0) + (badges.rappel || 0)
    };
    
    this.badgesSubject.next(updated);
    
    // Jouer un son si de nouvelles notifications
    if (this.hasNewNotifications(current, updated)) {
      this.playNotificationSound();
    }
    
    // Sauvegarder les paramètres
    this.saveSettings();
  }

  // Initialiser l'audio
  private initializeAudio(): void {
    try {
      this.audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      this.createNotificationSound();
    } catch (error) {
      console.warn('Audio non disponible:', error);
    }
  }

  // Créer le son de notification
  private createNotificationSound(): void {
    if (!this.audioContext) return;

    // Créer un son simple avec Web Audio API
    const oscillator = this.audioContext.createOscillator();
    const gainNode = this.audioContext.createGain();
    
    oscillator.connect(gainNode);
    gainNode.connect(this.audioContext.destination);
    
    // Fréquence et durée pour un son de notification agréable
    oscillator.frequency.value = 800; // Fréquence en Hz
    oscillator.type = 'sine'; // Forme d'onde douce
    
    // Créer un élément audio pour le son
    this.notificationSound = new Audio();
    this.notificationSound.volume = this.soundSettings.value.volume;
  }

  // Jouer le son de notification
  private playNotificationSound(): void {
    const settings = this.soundSettings.value;
    
    if (!settings.enabled) return;

    try {
      // Utiliser l'API Web Audio pour générer un son
      if (this.audioContext) {
        const oscillator = this.audioContext.createOscillator();
        const gainNode = this.audioContext.createGain();
        
        oscillator.connect(gainNode);
        gainNode.connect(this.audioContext.destination);
        
        // Son de notification doux
        oscillator.frequency.setValueAtTime(800, this.audioContext.currentTime);
        oscillator.frequency.setValueAtTime(1000, this.audioContext.currentTime + 0.1);
        oscillator.frequency.setValueAtTime(800, this.audioContext.currentTime + 0.2);
        
        gainNode.gain.setValueAtTime(settings.volume, this.audioContext.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, this.audioContext.currentTime + 0.3);
        
        oscillator.start(this.audioContext.currentTime);
        oscillator.stop(this.audioContext.currentTime + 0.3);
      }
    } catch (error) {
      console.warn('Erreur lors de la lecture du son:', error);
    }
  }

  // Vérifier s'il y a de nouvelles notifications
  private hasNewNotifications(old: BadgeNotification, updated: BadgeNotification): boolean {
    return updated.total > old.total;
  }

  // Mettre à jour les paramètres sonores
  updateSoundSettings(settings: Partial<NotificationSound>): void {
    const current = this.soundSettings.value;
    const updated = { ...current, ...settings };
    this.soundSettings.next(updated);
    this.saveSettings();
  }

  // Charger les paramètres depuis localStorage
  private loadSettings(): void {
    try {
      const saved = localStorage.getItem('notificationSettings');
      if (saved) {
        const settings = JSON.parse(saved);
        this.soundSettings.next({ ...this.soundSettings.value, ...settings });
      }
    } catch (error) {
      console.warn('Erreur lors du chargement des paramètres:', error);
    }
  }

  // Sauvegarder les paramètres
  private saveSettings(): void {
    try {
      localStorage.setItem('notificationSettings', JSON.stringify(this.soundSettings.value));
    } catch (error) {
      console.warn('Erreur lors de la sauvegarde des paramètres:', error);
    }
  }

  // Réinitialiser les badges
  resetBadges(): void {
    this.updateBadges({
      message: 0,
      critique: 0,
      rappel: 0
    });
  }

  // Tester le son de notification
  testNotificationSound(): void {
    this.playNotificationSound();
  }
}
