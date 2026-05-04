import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';

export interface TokenErrorInfo {
  type: 'expired' | 'invalid' | 'missing' | 'network';
  message: string;
  details?: string;
  recommendations?: string[];
}

@Component({
  selector: 'app-token-error-modal',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="token-error-overlay" [class.visible]="visible" (click)="onOverlayClick($event)">
      <div class="token-error-modal" [class.visible]="visible">
        <div class="modal-header">
          <div class="error-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" stroke="#ef4444" stroke-width="2"/>
              <line x1="15" y1="9" x2="9" y2="15" stroke="#ef4444" stroke-width="2" stroke-linecap="round"/>
              <line x1="9" y1="9" x2="15" y2="15" stroke="#ef4444" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </div>
          <div class="error-title">
            <h2>Problème d'authentification</h2>
            <p class="error-type">{{getErrorTitle(errorInfo?.type)}}</p>
          </div>
          <button class="close-btn" (click)="onClose()">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
              <line x1="18" y1="6" x2="6" y2="18" stroke="#6b7280" stroke-width="2" stroke-linecap="round"/>
              <line x1="6" y1="6" x2="18" y2="18" stroke="#6b7280" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </button>
        </div>

        <div class="modal-content">
          <div class="error-message">
            <p>{{errorInfo?.message || defaultMessage}}</p>
            <p class="error-details" *ngIf="errorInfo?.details">{{errorInfo?.details}}</p>
          </div>

          <div class="recommendations" *ngIf="errorInfo?.recommendations?.length">
            <h3>Recommandations</h3>
            <ul>
              <li *ngFor="let rec of errorInfo?.recommendations">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                  <circle cx="12" cy="12" r="10" stroke="#10b981" stroke-width="2"/>
                  <polyline points="8 12 11 15 16 9" stroke="#10b981" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                {{rec}}
              </li>
            </ul>
          </div>

          <div class="technical-info">
            <details>
              <summary>Informations techniques</summary>
              <div class="tech-details">
                <p><strong>Type:</strong> {{errorInfo?.type || 'Inconnu'}}</p>
                <p><strong>Timestamp:</strong> {{timestamp}}</p>
                <p><strong>Session ID:</strong> {{sessionId}}</p>
              </div>
            </details>
          </div>
        </div>

        <div class="modal-actions">
          <button class="btn-secondary" (click)="onClose()">
            Fermer
          </button>
          <button class="btn-primary" (click)="onReconnect()">
            Se reconnecter
          </button>
        </div>
      </div>
    </div>
  `,
  styles: [`
    .token-error-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(4px);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 9999;
      opacity: 0;
      visibility: hidden;
      transition: all 0.3s ease;
    }

    .token-error-overlay.visible {
      opacity: 1;
      visibility: visible;
    }

    .token-error-modal {
      background: white;
      border-radius: 16px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
      max-width: 500px;
      width: 90%;
      max-height: 80vh;
      overflow: hidden;
      transform: scale(0.9) translateY(20px);
      transition: all 0.3s ease;
    }

    .token-error-modal.visible {
      transform: scale(1) translateY(0);
    }

    .modal-header {
      display: flex;
      align-items: center;
      padding: 24px;
      border-bottom: 1px solid #e5e7eb;
      background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
    }

    .error-icon {
      margin-right: 16px;
      animation: pulse 2s infinite;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.7; }
    }

    .error-title h2 {
      margin: 0;
      font-size: 1.5rem;
      font-weight: 700;
      color: #1f2937;
    }

    .error-type {
      margin: 4px 0 0 0;
      color: #ef4444;
      font-weight: 500;
      font-size: 0.875rem;
    }

    .close-btn {
      margin-left: auto;
      background: none;
      border: none;
      padding: 8px;
      border-radius: 8px;
      cursor: pointer;
      transition: background-color 0.2s;
    }

    .close-btn:hover {
      background: rgba(107, 114, 128, 0.1);
    }

    .modal-content {
      padding: 24px;
      max-height: 400px;
      overflow-y: auto;
    }

    .error-message p {
      margin: 0 0 16px 0;
      color: #4b5563;
      line-height: 1.6;
    }

    .error-details {
      color: #6b7280;
      font-size: 0.875rem;
      font-style: italic;
    }

    .recommendations {
      margin: 24px 0;
      padding: 16px;
      background: #f0fdf4;
      border: 1px solid #bbf7d0;
      border-radius: 12px;
    }

    .recommendations h3 {
      margin: 0 0 12px 0;
      color: #166534;
      font-size: 1rem;
      font-weight: 600;
    }

    .recommendations ul {
      margin: 0;
      padding: 0;
      list-style: none;
    }

    .recommendations li {
      display: flex;
      align-items: flex-start;
      margin-bottom: 8px;
      color: #15803d;
      line-height: 1.5;
    }

    .recommendations li svg {
      margin-right: 8px;
      flex-shrink: 0;
      margin-top: 2px;
    }

    .recommendations li:last-child {
      margin-bottom: 0;
    }

    .technical-info {
      margin-top: 24px;
    }

    .technical-info details {
      border: 1px solid #e5e7eb;
      border-radius: 8px;
      overflow: hidden;
    }

    .technical-info summary {
      padding: 12px 16px;
      background: #f9fafb;
      cursor: pointer;
      font-weight: 500;
      color: #6b7280;
      border: none;
      outline: none;
    }

    .technical-info summary:hover {
      background: #f3f4f6;
    }

    .tech-details {
      padding: 16px;
      background: white;
      border-top: 1px solid #e5e7eb;
    }

    .tech-details p {
      margin: 0 0 8px 0;
      font-family: 'Courier New', monospace;
      font-size: 0.75rem;
      color: #6b7280;
    }

    .tech-details p:last-child {
      margin-bottom: 0;
    }

    .modal-actions {
      display: flex;
      gap: 12px;
      padding: 24px;
      border-top: 1px solid #e5e7eb;
      background: #f9fafb;
    }

    .btn-secondary {
      flex: 1;
      padding: 12px 24px;
      border: 1px solid #d1d5db;
      background: white;
      color: #6b7280;
      border-radius: 8px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s;
    }

    .btn-secondary:hover {
      background: #f9fafb;
      border-color: #9ca3af;
    }

    .btn-primary {
      flex: 1;
      padding: 12px 24px;
      border: none;
      background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
      color: white;
      border-radius: 8px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.2s;
    }

    .btn-primary:hover {
      background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
    }

    @media (max-width: 640px) {
      .token-error-modal {
        width: 95%;
        margin: 16px;
      }

      .modal-header {
        padding: 20px;
      }

      .modal-content {
        padding: 20px;
      }

      .modal-actions {
        flex-direction: column;
        padding: 20px;
      }
    }
  `]
})
export class TokenErrorModalComponent {
  @Input() visible = false;
  @Input() errorInfo: TokenErrorInfo | null = null;
  @Output() close = new EventEmitter<void>();
  @Output() reconnect = new EventEmitter<void>();

  timestamp = new Date();
  sessionId = this.generateSessionId();

  get defaultMessage(): string {
    return 'Une erreur d\'authentification s\'est produite.';
  }

  private generateSessionId(): string {
    return Math.random().toString(36).substr(2, 9).toUpperCase();
  }

  getErrorTitle(type?: string): string {
    switch (type) {
      case 'expired':
        return 'Session expirée';
      case 'invalid':
        return 'Token invalide';
      case 'missing':
        return 'Authentification requise';
      case 'network':
        return 'Problème de connexion';
      default:
        return 'Erreur d\'authentification';
    }
  }

  onClose(): void {
    this.close.emit();
  }

  onReconnect(): void {
    this.reconnect.emit();
  }

  onOverlayClick(event: MouseEvent): void {
    if (event.target === event.currentTarget) {
      this.onClose();
    }
  }
}
