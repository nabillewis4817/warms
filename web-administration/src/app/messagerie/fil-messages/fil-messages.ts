import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute } from '@angular/router';

import { MessageConversation, Messagerie } from '../../noyau/services/messagerie';

@Component({
  selector: 'app-fil-messages',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './fil-messages.html',
  styleUrl: './fil-messages.scss',
})
export class FilMessages implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly fb = inject(FormBuilder);
  private readonly messagerie = inject(Messagerie);
  messages: MessageConversation[] = [];
  conversationId = 0;

  form = this.fb.group({
    contenu: ['', Validators.required],
  });

  ngOnInit(): void {
    this.conversationId = Number(this.route.snapshot.paramMap.get('id'));
    this.charger();
  }

  charger(): void {
    this.messagerie.listerMessages(this.conversationId).subscribe({
      next: (items) => (this.messages = items),
    });
  }

  envoyer(): void {
    if (this.form.invalid) return;
    this.messagerie
      .envoyerMessage(this.conversationId, this.form.getRawValue().contenu ?? '')
      .subscribe({
        next: () => {
          this.form.reset();
          this.charger();
        },
      });
  }
}

// #EbaJioloLewis
