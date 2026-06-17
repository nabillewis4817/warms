import { Injectable, signal } from '@angular/core';
import { Patient } from './patients';

@Injectable({ providedIn: 'root' })
export class SelecteurPatientService {
  readonly ouvert   = signal(false);
  readonly recherche = signal('');
  readonly filtres   = signal<Patient[]>([]);
  readonly temp      = signal<Patient | null>(null);

  private tous: Patient[] = [];
  private cb: ((p: Patient) => void) | null = null;

  ouvrir(patients: Patient[], selection: Patient | null, onValider: (p: Patient) => void): void {
    this.tous = patients;
    this.filtres.set(patients);
    this.temp.set(selection);
    this.recherche.set('');
    this.cb = onValider;
    this.ouvert.set(true);
  }

  fermer(): void {
    this.ouvert.set(false);
    this.temp.set(null);
    this.recherche.set('');
  }

  filtrer(q: string): void {
    this.recherche.set(q);
    const lc = q.toLowerCase().trim();
    this.filtres.set(
      lc
        ? this.tous.filter(p =>
            `${p.prenom} ${p.nom}`.toLowerCase().includes(lc) ||
            (p.numero_dossier ?? '').toLowerCase().includes(lc)
          )
        : this.tous
    );
  }

  choisir(p: Patient): void { this.temp.set(p); }

  valider(): void {
    const p = this.temp();
    if (!p) return;
    this.cb?.(p);
    this.fermer();
  }

  initiales(p: Patient): string {
    return ((p.prenom ?? '').charAt(0) + (p.nom ?? '').charAt(0)).toUpperCase();
  }
}
