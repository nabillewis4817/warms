import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Nl2brPipe } from './nl2br.pipe';
import { WarmsIAService, WarmsIARequest, WarmsIAResponse } from '../../noyau/services/warms-ia';

@Component({
  selector: 'app-ia-warms',
  imports: [CommonModule, ReactiveFormsModule, Nl2brPipe],
  templateUrl: './ia-warms.html',
  styleUrl: './ia-warms.scss',
})
export class IaWarms implements OnInit {
  form: any;
  
  messages: Array<{
    role: 'user' | 'assistant';
    content: string;
    timestamp: Date;
  }> = [];

  chargement = false;

  constructor(
    private fb: FormBuilder,
    private warmsIAService: WarmsIAService
  ) {
    this.form = this.fb.group({
      message: ['', Validators.required],
    });
  }

  ngOnInit(): void {
    // Message de bienvenue
    this.messages.push({
      role: 'assistant',
      content: ' Bonjour ! Je suis Wams, votre assistant médical intelligent. Je peux vous aider avec :\n\n• Questions médicales générales\n• Informations sur les traitements\n• Conseils de santé\n• Aide à l\'utilisation de l\'application\n\nComment puis-je vous aider aujourd\'hui ?',
      timestamp: new Date()
    });
  }

  envoyerMessage(): void {
    if (this.form.invalid || this.chargement) return;

    const message = this.form.value.message?.trim();
    if (!message) return;

    // Ajouter le message de l'utilisateur
    this.messages.push({
      role: 'user',
      content: message,
      timestamp: new Date()
    });

    this.chargement = true;
    this.form.reset();

    // Appeler le service WARMS IA
    const request: WarmsIARequest = {
      question: message
    };

    this.warmsIAService.poserQuestion(request).subscribe({
      next: (response: WarmsIAResponse) => {
        this.messages.push({
          role: 'assistant',
          content: response.reponse,
          timestamp: new Date(response.timestamp)
        });
        this.chargement = false;
      },
      error: (error) => {
        console.error('Erreur WARMS IA:', error);
        
        // Afficher un message d'erreur clair sans fallback statique
        let errorMessage = 'Une erreur est survenue. ';
        
        if (error.status === 401) {
          errorMessage += 'Veuillez vous reconnecter et réessayer.';
        } else if (error.status === 403) {
          errorMessage += 'Vous n\'avez pas les permissions nécessaires pour utiliser cette fonctionnalité.';
        } else if (error.status === 500) {
          errorMessage += 'Le serveur rencontre des difficultés. Veuillez réessayer plus tard.';
        } else if (error.status === 0) {
          errorMessage += 'Impossible de contacter le serveur. Vérifiez votre connexion.';
        } else {
          errorMessage += `Erreur ${error.status}: ${error.message || 'Erreur inconnue'}`;
        }
        
        this.messages.push({
          role: 'assistant',
          content: errorMessage,
          timestamp: new Date()
        });
        
        this.chargement = false;
      }
    });
  }

  
  trackMessageId(index: number): number {
    return index;
  }

  suggestionClick(message: string): void {
    this.form.patchValue({ message });
    this.envoyerMessage();
  }
}
