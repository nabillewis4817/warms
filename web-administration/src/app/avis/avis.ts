import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { AvisService, Avis as AvisItem, AvisStatistiques } from '../noyau/services/avis.service';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-avis',
  imports: [CommonModule, ReactiveFormsModule, FormsModule],
  templateUrl: './avis.html',
  styleUrl: './avis.scss',
})
export class Avis implements OnInit {
  private readonly avisService = inject(AvisService);
  private readonly fb = inject(FormBuilder);

  avis: AvisItem[] = [];
  statistiques: AvisStatistiques | null = null;
  loading = false;
  erreur = '';
  avisSelectionne: AvisItem | null = null;
  showReponseModal = false;
  reponseEnCours = '';
  message = '';

  filtresForm = this.fb.group({
    recherche: [''],
    type_avis: [''],
    statut: [''],
    note_min: [''],
    note_max: [''],
  });

  readonly typesAvis = [
    { value: 'consultation', label: 'Consultation' },
    { value: 'traitement', label: 'Traitement' },
    { value: 'accueil', label: 'Accueil' },
    { value: 'installations', label: 'Installations' },
    { value: 'personnel', label: 'Personnel' },
    { value: 'general', label: 'Général' },
  ];

  readonly statuts = [
    { value: 'publie', label: 'Publié' },
    { value: 'modere', label: 'Modéré' },
    { value: 'masque', label: 'Masqué' },
    { value: 'signale', label: 'Signalé' },
  ];

  ngOnInit(): void {
    this.chargerAvis();
    this.chargerStatistiques();
  }

  chargerAvis(): void {
    this.loading = true;
    this.erreur = '';
    const filtres = this.filtresForm.value;
    const params = Object.fromEntries(
      Object.entries(filtres).filter(([, v]) => v !== '' && v !== null)
    );
    this.avisService.lister(params).subscribe({
      next: (data) => {
        this.avis = data;
        this.loading = false;
      },
      error: () => {
        this.erreur = 'Impossible de charger les avis.';
        this.loading = false;
      },
    });
  }

  chargerStatistiques(): void {
    this.avisService.statistiques().subscribe({
      next: (stats) => (this.statistiques = stats),
      error: () => {},
    });
  }

  appliquerFiltres(): void {
    this.chargerAvis();
  }

  reinitialiserFiltres(): void {
    this.filtresForm.reset({ recherche: '', type_avis: '', statut: '', note_min: '', note_max: '' });
    this.chargerAvis();
  }

  ouvrirReponse(avis: AvisItem): void {
    this.avisSelectionne = avis;
    this.reponseEnCours = avis.reponse_personnel || '';
    this.showReponseModal = true;
  }

  fermerReponse(): void {
    this.showReponseModal = false;
    this.avisSelectionne = null;
    this.reponseEnCours = '';
  }

  envoyerReponse(): void {
    if (!this.avisSelectionne || !this.reponseEnCours.trim()) return;
    this.avisService.repondre(this.avisSelectionne.id, this.reponseEnCours).subscribe({
      next: () => {
        this.message = 'Réponse envoyée avec succès.';
        this.fermerReponse();
        this.chargerAvis();
        setTimeout(() => (this.message = ''), 4000);
      },
      error: () => {
        this.message = "Erreur lors de l'envoi de la réponse.";
        setTimeout(() => (this.message = ''), 4000);
      },
    });
  }

  moderer(avis: AvisItem, statut: string): void {
    this.avisService.moderer(avis.id, statut).subscribe({
      next: () => {
        this.message = `Avis ${statut === 'masque' ? 'masqué' : 'modéré'} avec succès.`;
        this.chargerAvis();
        setTimeout(() => (this.message = ''), 4000);
      },
      error: () => {
        this.message = 'Erreur lors de la modération.';
        setTimeout(() => (this.message = ''), 4000);
      },
    });
  }

  etoiles(note: number): number[] {
    return Array.from({ length: 5 }, (_, i) => i + 1);
  }

  getNoteColor(note: number): string {
    if (note >= 4) return '#28a745';
    if (note >= 3) return '#ffc107';
    return '#dc3545';
  }

  getStatutBadge(statut: string): string {
    switch (statut) {
      case 'publie': return 'badge-success';
      case 'modere': return 'badge-warning';
      case 'masque': return 'badge-secondary';
      case 'signale': return 'badge-danger';
      default: return 'badge-secondary';
    }
  }

  getStatutLabel(statut: string): string {
    return this.statuts.find((s) => s.value === statut)?.label ?? statut;
  }

  getTypeLabel(type: string): string {
    return this.typesAvis.find((t) => t.value === type)?.label ?? type;
  }
}

// #EbaJioloLewis
