import { Component, Input, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AlerteService, AlerteMessage } from '../../services/alerte.service';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-alerte',
  imports: [CommonModule],
  templateUrl: './alerte.component.html',
  styleUrl: './alerte.component.scss'
})
export class AlerteComponent implements OnInit, OnDestroy {
  @Input() alerte!: AlerteMessage;
  private alerteSubscription!: Subscription;

  constructor(private alerteService: AlerteService) {}

  ngOnInit(): void {
    this.alerteSubscription = this.alerteService.alerte$.subscribe(alerte => {
      if (alerte) {
        this.alerte = alerte;
      }
    });
  }

  ngOnDestroy(): void {
    if (this.alerteSubscription) {
      this.alerteSubscription.unsubscribe();
    }
  }

  fermerAlerte(): void {
    this.alerteService.fermerAlerte();
  }

  getIcone(): string {
    // Utiliser l'icône personnalisée si disponible, sinon utiliser l'icône par défaut selon le type
    if (this.alerte.icone) {
      return this.alerte.icone;
    }
    
    const icones = {
      erreur: 'bi-x-circle-fill',
      warning: 'bi-exclamation-triangle-fill',
      success: 'bi-check-circle-fill',
      info: 'bi-info-circle-fill'
    };
    return icones[this.alerte.type] || 'bi-info-circle-fill';
  }

  getCouleurFond(): string {
    const couleurs = {
      erreur: '#dc2626',
      warning: '#f59e0b',
      success: '#10b981',
      info: '#3b82f6'
    };
    return couleurs[this.alerte.type] || '#3b82f6';
  }

  getCouleurBordure(): string {
    const couleurs = {
      erreur: '#b91c1c',
      warning: '#d97706',
      success: '#059669',
      info: '#2563eb'
    };
    return couleurs[this.alerte.type] || '#2563eb';
  }
}
