import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Subscription } from 'rxjs';
import { TokenErrorService } from '../services/token-error.service';
import { TokenErrorModalComponent } from './token-error-modal.component';

@Component({
  selector: 'app-global-token-error-handler',
  standalone: true,
  imports: [CommonModule, TokenErrorModalComponent],
  template: `
    <app-token-error-modal
      [visible]="visible"
      [errorInfo]="currentError"
      (close)="onClose()"
      (reconnect)="onReconnect()">
    </app-token-error-modal>
  `
})
export class GlobalTokenErrorHandlerComponent implements OnInit, OnDestroy {
  visible = false;
  currentError: any = null;
  private subscriptions = new Subscription();

  constructor(private tokenErrorService: TokenErrorService) {}

  ngOnInit(): void {
    // S'abonner aux erreurs de token
    const errorSub = this.tokenErrorService.error$.subscribe(error => {
      this.currentError = error;
    });

    const visibleSub = this.tokenErrorService.visible$.subscribe(visible => {
      this.visible = visible;
    });

    this.subscriptions.add(errorSub);
    this.subscriptions.add(visibleSub);
  }

  ngOnDestroy(): void {
    this.subscriptions.unsubscribe();
  }

  onClose(): void {
    this.tokenErrorService.hideError();
  }

  onReconnect(): void {
    this.tokenErrorService.handleReconnect();
  }
}
