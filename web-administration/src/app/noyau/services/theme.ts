import { Injectable, signal } from '@angular/core';

export type CouleurTheme = 'bleu' | 'vert' | 'rouge' | 'rose' | 'jaune';

const COULEURS_VALIDES: CouleurTheme[] = ['bleu', 'vert', 'rouge', 'rose', 'jaune'];

@Injectable({
  providedIn: 'root',
})
export class ThemeService {
  readonly modeSombre = signal(false);
  readonly couleur = signal<CouleurTheme>('bleu');

  appliquer(modeSombre: boolean): void {
    this.modeSombre.set(modeSombre);
    document.body.classList.toggle('theme-sombre', modeSombre);
    document.documentElement.classList.toggle('theme-sombre', modeSombre);
    document.documentElement.style.colorScheme = modeSombre ? 'dark' : 'light';
    localStorage.setItem('warms_mode_sombre', String(modeSombre));
  }

  appliquerCouleur(couleur: CouleurTheme): void {
    const valeur = COULEURS_VALIDES.includes(couleur) ? couleur : 'bleu';
    this.couleur.set(valeur);
    document.body.setAttribute('data-couleur', valeur);
    localStorage.setItem('warms_couleur', valeur);
  }

  restaurerDepuisStockageLocal(): void {
    const sombre = localStorage.getItem('warms_mode_sombre') === 'true';
    const couleur = (localStorage.getItem('warms_couleur') as CouleurTheme) || 'bleu';
    this.appliquer(sombre);
    this.appliquerCouleur(couleur);
  }
}

// #EbaJioloLewis
