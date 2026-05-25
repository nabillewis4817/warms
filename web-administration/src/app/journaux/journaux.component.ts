import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { JournauxService, Journal, JournalFilters } from '../noyau/services/journaux.service';

@Component({
  selector: 'app-journaux',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './journaux.component.html',
  styleUrl: './journaux.component.scss'
})
export class JournauxComponent implements OnInit {
  form: any;
  journaux: Journal[] = [];
  journauxFiltres: Journal[] = [];
  chargement = false;
  erreurChargement = '';
  journalSelectionne: Journal | null = null;
  filtre = '';
  typesJournaux: string[] = [];
  utilisateurs: string[] = [];

  constructor(
    private fb: FormBuilder,
    private router: Router,
    private journauxService: JournauxService
  ) {
    this.form = this.fb.group({
      recherche: [''],
      dateDebut: [''],
      dateFin: [''],
      type: [''],
      utilisateur: ['']
    });
  }

  ngOnInit(): void {
    this.chargerJournaux();
    this.chargerTypesEtUtilisateurs();
  }

  chargerJournaux(): void {
    this.chargement = true;
    this.erreurChargement = '';
    const filters: JournalFilters = this.form.value;
    
    this.journauxService.getJournaux(filters).subscribe({
      next: (data) => {
        this.journaux = data;
        this.journauxFiltres = data;
        this.chargement = false;
      },
      error: (error) => {
        console.error('Erreur lors du chargement des journaux:', error);
        this.journaux = [];
        this.journauxFiltres = [];
        this.erreurChargement = 'Impossible de charger les journaux. Vérifiez la connexion au serveur.';
        this.chargement = false;
      }
    });
  }

  filtrerJournaux(): void {
    const filtreTexte = this.form.value.recherche?.toLowerCase() || '';
    const filtreType = this.form.value.type || '';
    const filtreUtilisateur = this.form.value.utilisateur?.toLowerCase() || '';
    const filtreDateDebut = this.form.value.dateDebut || '';
    const filtreDateFin = this.form.value.dateFin || '';
    
    this.journauxFiltres = this.journaux.filter(journal => {
      // Filtre par texte
      const matchTexte = !filtreTexte || 
        journal.action.toLowerCase().includes(filtreTexte) ||
        journal.details.toLowerCase().includes(filtreTexte) ||
        journal.utilisateur.toLowerCase().includes(filtreTexte);
      
      // Filtre par type
      const matchType = !filtreType || journal.type === filtreType;
      
      // Filtre par utilisateur
      const matchUtilisateur = !filtreUtilisateur || 
        journal.utilisateur.toLowerCase().includes(filtreUtilisateur);
      
      // Filtre par date
      const journalDate = new Date(journal.date);
      const dateDebut = filtreDateDebut ? new Date(filtreDateDebut) : null;
      const dateFin = filtreDateFin ? new Date(filtreDateFin) : null;
      
      const matchDateDebut = !dateDebut || journalDate >= dateDebut;
      const matchDateFin = !dateFin || journalDate <= dateFin;
      
      return matchTexte && matchType && matchUtilisateur && matchDateDebut && matchDateFin;
    });
  }

  exporterJournaux(): void {
    const filters: JournalFilters = this.form.value;
    
    this.journauxService.exporterJournaux(filters).subscribe({
      next: (blob) => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `journaux_${new Date().toISOString().split('T')[0]}.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
      },
      error: (error) => {
        console.error('Erreur lors de l\'exportation des journaux:', error);
        alert('Erreur lors de l\'exportation des journaux');
      }
    });
  }

  rafraichir(): void {
    this.chargerJournaux();
  }

  getIcone(type: string): string {
    const icones: { [key: string]: string } = {
      patient: 'bi-person-plus',
      consultation: 'bi-clipboard2',
      rendez_vous: 'bi-calendar-check',
      systeme: 'bi-gear',
      modification: 'bi-pencil',
      suppression: 'bi-trash',
      connexion: 'bi-box-arrow-in-right'
    };
    return icones[type] || 'bi-circle';
  }

  chargerTypesEtUtilisateurs(): void {
    // Charger les types de journaux disponibles
    this.journauxService.getTypesJournaux().subscribe({
      next: (types) => {
        this.typesJournaux = types;
      },
      error: (error) => {
        console.error('Erreur lors du chargement des types:', error);
        // Utiliser des types par défaut
        this.typesJournaux = ['patient', 'consultation', 'rendez_vous', 'systeme'];
      }
    });

    // Charger les utilisateurs disponibles
    this.journauxService.getUtilisateurs().subscribe({
      next: (utilisateurs) => {
        this.utilisateurs = utilisateurs;
      },
      error: (error) => {
        console.error('Erreur lors du chargement des utilisateurs:', error);
        // Utiliser des utilisateurs par défaut
        this.utilisateurs = ['Dr. Martin', 'Secrétaire', 'Dr. Dubois'];
      }
    });
  }

  resetFilters(): void {
    this.form.reset({
      recherche: '',
      dateDebut: '',
      dateFin: '',
      type: '',
      utilisateur: ''
    });
    this.filtrerJournaux();
  }

  getTypeLabel(type: string): string {
    const labels: { [key: string]: string } = {
      patient: 'Patient',
      consultation: 'Consultation',
      rendez_vous: 'Rendez-vous',
      systeme: 'Système',
      modification: 'Modification',
      suppression: 'Suppression',
      connexion: 'Connexion'
    };
    return labels[type] || type;
  }

  voirDetails(journal: Journal): void {
    this.journalSelectionne = journal;
  }

  fermerDetails(): void {
    this.journalSelectionne = null;
  }

  exporterJournal(journal: Journal): void {
    // Exporter une seule entrée de journal
    const csvContent = this.formatJournalToCSV([journal]);
    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `journal_${journal.id}_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
  }

  private formatJournalToCSV(journaux: Journal[]): string {
    const headers = ['ID', 'Date', 'Utilisateur', 'Action', 'Détails', 'Type'];
    const rows = journaux.map(journal => [
      journal.id,
      journal.date,
      journal.utilisateur,
      journal.action,
      journal.details,
      journal.type
    ]);
    
    return [headers, ...rows].map(row => row.join(',')).join('\n');
  }
}
