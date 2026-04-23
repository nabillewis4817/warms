import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, OnDestroy } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';
import { interval, Subscription } from 'rxjs';

import { MessageConversation, Messagerie } from '../../noyau/services/messagerie';

@Component({
  selector: 'app-fil-messages',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './fil-messages.html',
  styleUrl: './fil-messages.scss',
})
export class FilMessages implements OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly fb = inject(FormBuilder);
  private readonly messagerie = inject(Messagerie);
  messages: MessageConversation[] = [];
  conversationId = 0;
  chargement = false;
  private refreshSubscription: Subscription | null = null;

  form = this.fb.group({
    contenu: ['', Validators.required],
  });

  ngOnInit(): void {
    this.conversationId = Number(this.route.snapshot.paramMap.get('id'));
    this.charger();
    // Auto-refresh toutes les 10 secondes pour les messages
    this.refreshSubscription = interval(10000).subscribe(() => {
      this.charger();
    });
  }

  ngOnDestroy(): void {
    if (this.refreshSubscription) {
      this.refreshSubscription.unsubscribe();
    }
  }

  charger(): void {
    this.chargement = true;
    this.messagerie.listerMessages(this.conversationId).subscribe({
      next: (items) => {
        this.messages = items;
        this.chargement = false;
        this.defilerEnBas();
      },
      error: () => {
        this.chargement = false;
      }
    });
  }

  envoyer(): void {
    if (this.form.invalid) return;
    
    const message = this.form.getRawValue().contenu ?? '';
    this.form.reset();
    
    this.messagerie.envoyerMessage(this.conversationId, message).subscribe({
      next: () => {
        this.charger();
      },
      error: () => {
        // En cas d'erreur, restaurer le message
        this.form.patchValue({ contenu: message });
      }
    });
  }

  private defilerEnBas(): void {
    setTimeout(() => {
      const container = document.querySelector('.messages-container');
      if (container) {
        container.scrollTop = container.scrollHeight;
      }
    }, 100);
  }

  trackMessageId(index: number, message: MessageConversation): number {
    return message.id;
  }
}

// #EbaJioloLewis
