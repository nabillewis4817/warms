import { Injectable, signal } from '@angular/core';

type Langue = 'fr' | 'en';

const DICTIONNAIRE: Record<Langue, Record<string, string>> = {
  fr: {
    appTitle: "Warm's Cabinet",
    dashboard: 'Tableau de bord',
    settings: 'Paramètres',
    profile: 'Profil utilisateur',
    darkMode: 'Mode sombre',
    language: 'Langue',
    save: 'Enregistrer',
  },
  en: {
    appTitle: "Warm's Clinic",
    dashboard: 'Dashboard',
    settings: 'Settings',
    profile: 'User profile',
    darkMode: 'Dark mode',
    language: 'Language',
    save: 'Save',
  },
};

@Injectable({
  providedIn: 'root',
})
export class TraductionService {
  readonly langue = signal<Langue>('fr');

  definirLangue(langue: Langue): void {
    this.langue.set(langue);
  }

  t(cle: string): string {
    return DICTIONNAIRE[this.langue()][cle] ?? cle;
  }
}

// #EbaJioloLewis
