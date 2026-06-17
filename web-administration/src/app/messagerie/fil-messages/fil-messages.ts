import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, OnDestroy } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { interval, Subscription } from 'rxjs';
import { environment } from '../../../environments/environment';

import { Conversation, MessageConversation, Messagerie } from '../../noyau/services/messagerie';

@Component({
  selector: 'app-fil-messages',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './fil-messages.html',
  styleUrl: './fil-messages.scss',
})
export class FilMessages implements OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly fb = inject(FormBuilder);
  private readonly messagerie = inject(Messagerie);

  conversation: Conversation | null = null;
  messages: MessageConversation[] = [];
  conversationId = 0;
  chargement = false;
  envoiEnCours = false;
  wsConnecte = false;
  readonly username: string | null = this.obtenirUsernameConnecte();

  private ws: WebSocket | null = null;
  private wsReconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private refreshMessages: Subscription | null = null;
  private refreshConversation: Subscription | null = null;

  form = this.fb.group({
    contenu: ['', Validators.required],
  });

  ngOnInit(): void {
    this.conversationId = Number(this.route.snapshot.paramMap.get('id'));
    this.chargerConversation();
    this.charger();
    this.connecterWebSocket();
    // Polling de secours: messages toutes les 30s (WS gère le temps réel), infos toutes les 15s
    this.refreshMessages = interval(30000).subscribe(() => this.charger(true));
    this.refreshConversation = interval(15000).subscribe(() => this.chargerConversation());
  }

  ngOnDestroy(): void {
    this.refreshMessages?.unsubscribe();
    this.refreshConversation?.unsubscribe();
    if (this.wsReconnectTimer) clearTimeout(this.wsReconnectTimer);
    this.ws?.close();
    this.ws = null;
  }

  private connecterWebSocket(): void {
    const token = localStorage.getItem('warms_access') ?? '';
    const wsBase = environment.apiBaseUrl
      .replace(/^http:\/\//, 'ws://')
      .replace(/^https:\/\//, 'wss://')
      .replace('/api/v1', '');
    const url = `${wsBase}/ws/chat/${this.conversationId}/?token=${token}`;

    try {
      this.ws = new WebSocket(url);
    } catch {
      return;
    }

    this.ws.onopen = () => {
      this.wsConnecte = true;
    };

    this.ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.message) {
          this.ajouterMessage(data.message as MessageConversation);
        }
      } catch { /* ignore malformed frames */ }
    };

    this.ws.onclose = () => {
      this.wsConnecte = false;
      this.ws = null;
      // Reconnexion automatique dans 5 secondes
      this.wsReconnectTimer = setTimeout(() => this.connecterWebSocket(), 5000);
    };

    this.ws.onerror = () => {
      this.ws?.close();
    };
  }

  private ajouterMessage(msg: MessageConversation): void {
    if (!this.messages.some((m) => m.id === msg.id)) {
      this.messages = [...this.messages, msg];
      this.defilerEnBas();
    }
  }

  chargerConversation(): void {
    this.messagerie.detailConversation(this.conversationId).subscribe({
      next: (conversation) => (this.conversation = conversation),
      error: () => undefined,
    });
  }

  charger(silencieux = false): void {
    if (!silencieux) this.chargement = true;
    this.messagerie.listerMessages(this.conversationId).subscribe({
      next: (items) => {
        const nouveauxMessages = items.length > this.messages.length;
        this.messages = items;
        this.chargement = false;
        if (!silencieux || nouveauxMessages) this.defilerEnBas();
      },
      error: () => { this.chargement = false; },
    });
  }

  envoyer(): void {
    if (this.form.invalid || this.envoiEnCours) return;

    const message = this.form.getRawValue().contenu ?? '';
    this.form.reset();
    this.envoiEnCours = true;

    this.messagerie.envoyerMessage(this.conversationId, message).subscribe({
      next: () => {
        this.envoiEnCours = false;
        if (!this.wsConnecte) this.charger(true);
      },
      error: () => {
        this.envoiEnCours = false;
        this.form.patchValue({ contenu: message });
      },
    });
  }

  envoyerSuggestion(texte: string): void {
    this.messagerie.envoyerMessage(this.conversationId, texte).subscribe({
      next: () => { if (!this.wsConnecte) this.charger(true); },
    });
  }

  retour(): void {
    this.router.navigate(['/messagerie']);
  }

  voirDossierPatient(): void {
    if (!this.conversation?.patient) return;
    this.router.navigate(['/patients', this.conversation.patient, 'dossier']);
  }

  obtenirNomConversation(): string {
    if (!this.conversation) return 'Conversation';
    return this.conversation.patient_nom || this.conversation.titre || `Conversation #${this.conversation.id}`;
  }

  obtenirInitiale(): string {
    const source = this.conversation?.patient_nom || this.conversation?.titre || '?';
    return source.charAt(0).toUpperCase();
  }

  afficherSeparateurDate(index: number): boolean {
    if (index === 0) return true;
    const courant = new Date(this.messages[index].cree_le).toDateString();
    const precedent = new Date(this.messages[index - 1].cree_le).toDateString();
    return courant !== precedent;
  }

  obtenirLibelleDate(dateIso: string): string {
    const date = new Date(dateIso);
    const aujourdHui = new Date();
    const hier = new Date();
    hier.setDate(aujourdHui.getDate() - 1);

    if (date.toDateString() === aujourdHui.toDateString()) return "Aujourd'hui";
    if (date.toDateString() === hier.toDateString()) return 'Hier';
    return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  }

  private defilerEnBas(): void {
    setTimeout(() => {
      const container = document.querySelector('.messages-container');
      if (container) container.scrollTop = container.scrollHeight;
    }, 80);
  }

  private obtenirUsernameConnecte(): string | null {
    const userData = localStorage.getItem('utilisateur');
    return userData ? JSON.parse(userData).username ?? null : null;
  }
}

// #EbaJioloLewis
