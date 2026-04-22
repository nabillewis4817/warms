import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';

import { Conversation, Messagerie } from '../../noyau/services/messagerie';

@Component({
  selector: 'app-liste-conversations',
  imports: [CommonModule, RouterLink, FormsModule],
  templateUrl: './liste-conversations.html',
  styleUrl: './liste-conversations.scss',
})
export class ListeConversations implements OnInit {
  private readonly messagerie = inject(Messagerie);
  conversations: Conversation[] = [];
  titre = '';
  contact = '';

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.messagerie.listerConversations().subscribe({
      next: (items) => (this.conversations = items),
    });
  }

  creerConversation(): void {
    if (!this.titre.trim()) return;
    this.messagerie.creerConversation(this.titre).subscribe({
      next: () => {
        this.titre = '';
        this.charger();
      },
    });
  }

  enregistrerContact(): void {
    if (!this.contact.trim()) return;
    const deja = JSON.parse(localStorage.getItem('warms_contacts') || '[]') as string[];
    localStorage.setItem('warms_contacts', JSON.stringify([...deja, this.contact]));
    this.contact = '';
  }
}

// #EbaJioloLewis
