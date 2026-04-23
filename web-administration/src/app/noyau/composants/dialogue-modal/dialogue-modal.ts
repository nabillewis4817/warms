import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { Observable, Subject, takeUntil } from 'rxjs';
import { DialogueService, DialogueOptions } from '../../services/dialogue.service';

@Component({
  selector: 'app-dialogue-modal',
  imports: [CommonModule],
  templateUrl: './dialogue-modal.html',
  styleUrl: './dialogue-modal.scss'
})
export class DialogueModal implements OnInit, OnDestroy {
  visible = false;
  options: DialogueOptions | null = null;
  
  private destroy$ = new Subject<void>();

  constructor(private dialogueService: DialogueService) {}

  ngOnInit(): void {
    this.dialogueService.dialogue$
      .pipe(takeUntil(this.destroy$))
      .subscribe((options: DialogueOptions) => {
        this.options = options;
        this.visible = true;
      });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  confirmer(): void {
    this.dialogueService.fermerAvecResultat(true);
    this.visible = false;
  }

  annuler(): void {
    this.dialogueService.fermerAvecResultat(false);
    this.visible = false;
  }

  get icone(): string {
    switch (this.options?.type) {
      case 'confirmation': return 'bi-question-circle';
      case 'information': return 'bi-info-circle';
      case 'erreur': return 'bi-exclamation-triangle';
      case 'succes': return 'bi-check-circle';
      default: return 'bi-info-circle';
    }
  }

  get classeType(): string {
    switch (this.options?.type) {
      case 'confirmation': return 'dialogue-confirmation';
      case 'information': return 'dialogue-information';
      case 'erreur': return 'dialogue-erreur';
      case 'succes': return 'dialogue-succes';
      default: return 'dialogue-information';
    }
  }
}
