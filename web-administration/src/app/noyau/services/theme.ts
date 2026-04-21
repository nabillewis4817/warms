import { Injectable, signal } from '@angular/core';

@Injectable({
  providedIn: 'root',
})
export class ThemeService {
  readonly modeSombre = signal(false);

  appliquer(modeSombre: boolean): void {
    this.modeSombre.set(modeSombre);
    document.body.classList.toggle('theme-sombre', modeSombre);
  }
}

// #EbaJioloLewis
