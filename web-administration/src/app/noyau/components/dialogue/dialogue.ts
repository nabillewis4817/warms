import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';

import { DialogueService, DialogueOptions } from '../../services/dialogue.service';

@Component({
  selector: 'app-dialogue',
  imports: [CommonModule],
  templateUrl: './dialogue.html',
  styleUrl: './dialogue.scss'
})
export class DialogueComponent implements OnInit, OnDestroy {
  visible = false;
  options: DialogueOptions | null = null;
  private subscription: Subscription | null = null;

  constructor(private dialogueService: DialogueService) {}

  ngOnInit(): void {
    this.subscription = this.dialogueService.dialogue$.subscribe((options) => {
      this.options = options;
      this.visible = true;
    });
  }

  ngOnDestroy(): void {
    if (this.subscription) {
      this.subscription.unsubscribe();
    }
  }

  confirmer(): void {
    this.dialogueService.fermerAvecResultat(true);
    this.fermer();
  }

  annuler(): void {
    this.dialogueService.fermerAvecResultat(false);
    this.fermer();
  }

  fermer(): void {
    this.visible = false;
    this.options = null;
  }

  get icone(): string {
    switch (this.options?.type) {
      case 'confirmation':
        return 'bi bi-question-circle';
      case 'information':
        return 'bi bi-info-circle';
      case 'erreur':
        return 'bi bi-exclamation-triangle';
      case 'succes':
        return 'bi bi-check-circle';
      default:
        return 'bi bi-info-circle';
    }
  }

  get classeType(): string {
    return `dialogue-${this.options?.type || 'information'}`;
  }
}
