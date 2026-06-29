import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { FormsModule } from '@angular/forms';

import { Rappel, RappelsService } from '../noyau/services/rappels.service';

type TypeEntree = 'note' | 'rappel';

@Component({
  selector: 'app-agenda',
  imports: [CommonModule, ReactiveFormsModule, FormsModule],
  templateUrl: './agenda.html',
  styleUrl: './agenda.scss',
})
export class Agenda implements OnInit {
  private readonly rappelsService = inject(RappelsService);
  private readonly fb = inject(FormBuilder);

  rappels: Rappel[] = [];
  chargement = false;
  erreur = '';

  formulaireOuvert = false;
  enregistrementEnCours = false;
  entreeEnEdition: Rappel | null = null;
  typeEntree: TypeEntree = 'note';

  readonly recurrences = [
    { value: 'aucune', label: 'Une seule fois' },
    { value: 'quotidien', label: 'Tous les jours' },
    { value: 'hebdomadaire', label: 'Toutes les semaines' },
    { value: 'mensuel', label: 'Tous les mois' },
  ];

  formulaire = this.fb.group({
    titre: ['', [Validators.required, Validators.maxLength(255)]],
    message: ['', [Validators.maxLength(500)]],
    date: [''],
    heure: [''],
    recurrence: ['aucune'],
  });

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement = true;
    this.erreur = '';
    this.rappelsService.lister().subscribe({
      next: (data) => {
        this.rappels = data;
        this.chargement = false;
      },
      error: () => {
        this.erreur = "Impossible de charger l'agenda.";
        this.chargement = false;
      },
    });
  }

  // ==================== GROUPEMENT PAR DATE ====================

  private debutJour(date: Date): number {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  }

  get entreesAujourdhui(): Rappel[] {
    const aujourdhui = this.debutJour(new Date());
    return this.rappels.filter((r) => this.debutJour(new Date(r.date_heure)) === aujourdhui);
  }

  get entreesAVenir(): Rappel[] {
    const aujourdhui = this.debutJour(new Date());
    return this.rappels
      .filter((r) => this.debutJour(new Date(r.date_heure)) > aujourdhui)
      .sort((a, b) => new Date(a.date_heure).getTime() - new Date(b.date_heure).getTime());
  }

  get entreesPassees(): Rappel[] {
    const aujourdhui = this.debutJour(new Date());
    return this.rappels
      .filter((r) => this.debutJour(new Date(r.date_heure)) < aujourdhui)
      .sort((a, b) => new Date(b.date_heure).getTime() - new Date(a.date_heure).getTime());
  }

  get aucuneEntree(): boolean {
    return !this.chargement && this.rappels.length === 0;
  }

  // ==================== AFFICHAGE ====================

  iconePour(r: Rappel): string {
    return r.recurrence !== 'aucune' ? 'bi-arrow-repeat' : 'bi-sticky';
  }

  labelRecurrence(valeur: string): string {
    return this.recurrences.find((r) => r.value === valeur)?.label ?? valeur;
  }

  formaterHeure(dateIso: string): string {
    return new Date(dateIso).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  }

  formaterDateCourte(dateIso: string): string {
    return new Date(dateIso).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });
  }

  // ==================== FORMULAIRE ====================

  ouvrirNouveau(type: TypeEntree): void {
    this.typeEntree = type;
    this.entreeEnEdition = null;
    const maintenant = new Date();
    this.formulaire.reset({
      titre: '',
      message: '',
      date: maintenant.toISOString().slice(0, 10),
      heure: maintenant.toTimeString().slice(0, 5),
      recurrence: 'aucune',
    });
    this.formulaireOuvert = true;
  }

  ouvrirEdition(r: Rappel): void {
    this.typeEntree = r.recurrence === 'aucune' ? 'note' : 'rappel';
    this.entreeEnEdition = r;
    const d = new Date(r.date_heure);
    this.formulaire.reset({
      titre: r.titre,
      message: r.message,
      date: d.toISOString().slice(0, 10),
      heure: d.toTimeString().slice(0, 5),
      recurrence: r.recurrence,
    });
    this.formulaireOuvert = true;
  }

  fermerFormulaire(): void {
    this.formulaireOuvert = false;
    this.entreeEnEdition = null;
  }

  enregistrer(): void {
    if (this.formulaire.invalid) {
      this.formulaire.markAllAsTouched();
      return;
    }

    const v = this.formulaire.value;
    const dateHeure = new Date(`${v.date}T${v.heure || '09:00'}:00`);
    const payload = {
      titre: v.titre!.trim(),
      message: (v.message ?? '').trim(),
      date_heure: dateHeure.toISOString(),
      recurrence: this.typeEntree === 'note' ? ('aucune' as const) : (v.recurrence as Rappel['recurrence']),
    };

    this.enregistrementEnCours = true;
    const requete = this.entreeEnEdition
      ? this.rappelsService.modifier(this.entreeEnEdition.id, payload)
      : this.rappelsService.creer(payload);

    requete.subscribe({
      next: () => {
        this.enregistrementEnCours = false;
        this.fermerFormulaire();
        this.charger();
      },
      error: () => {
        this.enregistrementEnCours = false;
        this.erreur = "Impossible d'enregistrer cette entrée.";
      },
    });
  }

  basculerActif(r: Rappel): void {
    this.rappelsService.modifier(r.id, { actif: !r.actif }).subscribe({
      next: (maj) => {
        this.rappels = this.rappels.map((x) => (x.id === maj.id ? maj : x));
      },
    });
  }

  supprimer(r: Rappel): void {
    this.rappelsService.supprimer(r.id).subscribe({
      next: () => {
        this.rappels = this.rappels.filter((x) => x.id !== r.id);
      },
    });
  }
}
