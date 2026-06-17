import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { JournauxService, Journal, JournalFilters } from '../noyau/services/journaux.service';

interface InfoType {
  label: string;
  icone: string;
  couleur: string;
  fondClair: string;
}

@Component({
  selector: 'app-journaux',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './journaux.component.html',
  styleUrl: './journaux.component.scss',
})
export class JournauxComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly journauxService = inject(JournauxService);

  journaux: Journal[] = [];
  journauxFiltres: Journal[] = [];
  chargement = false;
  chargementExport = false;
  erreurChargement = '';
  journalSelectionne: Journal | null = null;
  statistiques: { total: number; par_type: Record<string, number> } | null = null;

  readonly typesDisponibles: { valeur: string; info: InfoType }[] = [
    { valeur: 'patient',      info: { label: 'Patient',      icone: 'bi-person-plus',         couleur: '#10b981', fondClair: '#d1fae5' } },
    { valeur: 'consultation', info: { label: 'Consultation', icone: 'bi-clipboard2-pulse',     couleur: '#f59e0b', fondClair: '#fef3c7' } },
    { valeur: 'rendez_vous',  info: { label: 'Rendez-vous',  icone: 'bi-calendar-check',       couleur: '#3b82f6', fondClair: '#dbeafe' } },
    { valeur: 'personnel',    info: { label: 'Personnel',    icone: 'bi-people',               couleur: '#8b5cf6', fondClair: '#ede9fe' } },
    { valeur: 'modification', info: { label: 'Modification', icone: 'bi-pencil-square',        couleur: '#6366f1', fondClair: '#e0e7ff' } },
    { valeur: 'suppression',  info: { label: 'Suppression',  icone: 'bi-trash3',               couleur: '#ef4444', fondClair: '#fee2e2' } },
    { valeur: 'connexion',    info: { label: 'Connexion',    icone: 'bi-box-arrow-in-right',   couleur: '#14b8a6', fondClair: '#ccfbf1' } },
    { valeur: 'ordonnance',   info: { label: 'Ordonnance',   icone: 'bi-file-medical',         couleur: '#ec4899', fondClair: '#fce7f3' } },
    { valeur: 'analyse',      info: { label: 'Analyse',      icone: 'bi-graph-up-arrow',       couleur: '#06b6d4', fondClair: '#cffafe' } },
    { valeur: 'systeme',      info: { label: 'Système',      icone: 'bi-gear-wide-connected',  couleur: '#6b7280', fondClair: '#f3f4f6' } },
  ];

  form = this.fb.group({
    recherche: [''],
    dateDebut: [''],
    dateFin: [''],
    type: [''],
  });

  ngOnInit(): void {
    this.chargerJournaux();
    this.chargerStatistiques();
  }

  chargerJournaux(): void {
    this.chargement = true;
    this.erreurChargement = '';

    this.journauxService.getJournaux().subscribe({
      next: (data) => {
        this.journaux = data;
        this.appliquerFiltres();
        this.chargement = false;
      },
      error: () => {
        this.erreurChargement = 'Impossible de charger les journaux. Vérifiez votre connexion au serveur.';
        this.chargement = false;
      },
    });
  }

  chargerStatistiques(): void {
    this.journauxService.getStatistiques().subscribe({
      next: (stats) => (this.statistiques = stats),
      error: () => undefined,
    });
  }

  appliquerFiltres(): void {
    const { recherche, type, dateDebut, dateFin } = this.form.value;
    const terme = (recherche ?? '').toLowerCase();

    this.journauxFiltres = this.journaux.filter((j) => {
      if (
        terme &&
        !j.action.toLowerCase().includes(terme) &&
        !j.details.toLowerCase().includes(terme) &&
        !j.utilisateur.toLowerCase().includes(terme) &&
        !this.humaniserAction(j.action).toLowerCase().includes(terme)
      ) {
        return false;
      }
      if (type && j.type !== type) return false;

      const date = new Date(j.date);
      if (dateDebut && date < new Date(dateDebut)) return false;
      if (dateFin && date > new Date(dateFin + 'T23:59:59')) return false;

      return true;
    });
  }

  private formToFilters(): JournalFilters {
    const v = this.form.value;
    return {
      recherche: v.recherche ?? undefined,
      dateDebut: v.dateDebut ?? undefined,
      dateFin: v.dateFin ?? undefined,
      type: v.type ?? undefined,
    };
  }

  exporterJournaux(): void {
    if (this.chargementExport) return;
    this.chargementExport = true;
    const filters = this.formToFilters();

    this.journauxService.exporterJournaux(filters).subscribe({
      next: (blob) => {
        this.telechargerBlob(blob, `journaux_warms_${new Date().toISOString().split('T')[0]}.csv`);
        this.chargementExport = false;
      },
      error: () => { this.chargementExport = false; },
    });
  }

  exporterJournalUnique(journal: Journal): void {
    const entetes = ['ID', 'Date', 'Utilisateur', 'Action', 'Détails', 'Type', 'Objet', 'IP'];
    const ligne = [
      journal.id,
      journal.date,
      `"${journal.utilisateur}"`,
      `"${this.humaniserAction(journal.action)}"`,
      `"${journal.details.replace(/"/g, '""')}"`,
      journal.type,
      journal.objet_type ? `${journal.objet_type} #${journal.objet_id}` : '',
      journal.adresse_ip ?? '',
    ];
    const csv = [entetes.join(','), ligne.join(',')].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    this.telechargerBlob(blob, `journal_${journal.id}.csv`);
  }

  private telechargerBlob(blob: Blob, nom: string): void {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = nom;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  }

  voirDetails(journal: Journal): void {
    this.journalSelectionne = journal;
  }

  fermerDetails(): void {
    this.journalSelectionne = null;
  }

  reinitialiserFiltres(): void {
    this.form.reset({ recherche: '', dateDebut: '', dateFin: '', type: '' });
    this.appliquerFiltres();
  }

  humaniserAction(action: string): string {
    const connus: Record<string, string> = {
      creation_patient: 'Création de patient',
      modification_patient: 'Modification de patient',
      suppression_patient: 'Suppression de patient',
      archivage_patient: 'Archivage de patient',
      restauration_patient: 'Restauration de patient',
      creation_consultation: 'Création de consultation',
      modification_consultation: 'Modification de consultation',
      suppression_consultation: 'Suppression de consultation',
      creation_rendez_vous: 'Création de rendez-vous',
      modification_rendez_vous: 'Modification de rendez-vous',
      suppression_rendez_vous: 'Suppression de rendez-vous',
      connexion: 'Connexion au système',
      deconnexion: 'Déconnexion du système',
      creation_personnel: 'Création de membre du personnel',
      modification_personnel: 'Modification de membre du personnel',
      suppression_personnel: 'Suppression de membre du personnel',
      creation_ordonnance: "Création d'ordonnance",
      modification_ordonnance: "Modification d'ordonnance",
      creation_analyse: "Création d'analyse",
      modification_analyse: "Modification d'analyse",
    };
    if (connus[action]) return connus[action];
    return action.replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase());
  }

  obtenirInfoType(type: string): InfoType {
    return (
      this.typesDisponibles.find((t) => t.valeur === type)?.info ?? {
        label: type,
        icone: 'bi-circle',
        couleur: '#6b7280',
        fondClair: '#f3f4f6',
      }
    );
  }

  obtenirInitiale(utilisateur: string): string {
    const parties = (utilisateur ?? 'S').split(' ');
    if (parties.length >= 2) return (parties[0][0] + parties[1][0]).toUpperCase();
    return parties[0].charAt(0).toUpperCase();
  }

  obtenirTempsRelatif(date: string): string {
    if (!date) return '';
    const diff = Math.floor((Date.now() - new Date(date).getTime()) / 1000);
    if (diff < 60) return 'à l\'instant';
    if (diff < 3600) return `il y a ${Math.floor(diff / 60)} min`;
    if (diff < 86400) return `il y a ${Math.floor(diff / 3600)} h`;
    if (diff < 604800) return `il y a ${Math.floor(diff / 86400)} j`;
    return new Date(date).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });
  }

  compterAujourdhui(): number {
    const auj = new Date().toISOString().split('T')[0];
    return this.journaux.filter((j) => j.date.startsWith(auj)).length;
  }
}

// #EbaJioloLewis
