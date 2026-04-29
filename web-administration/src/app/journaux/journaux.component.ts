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
  filtre = '';

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
  }

  chargerJournaux(): void {
    this.chargement = true;
    const filters: JournalFilters = this.form.value;
    
    this.journauxService.getJournaux(filters).subscribe({
      next: (data) => {
        this.journaux = data;
        this.journauxFiltres = data;
        this.chargement = false;
      },
      error: (error) => {
        console.error('Erreur lors du chargement des journaux:', error);
        this.chargement = false;
        // En cas d'erreur, utiliser des données de démonstration
        this.journaux = this.getDonneesDemonstration();
        this.journauxFiltres = this.journaux;
      }
    });
  }

  filtrerJournaux(): void {
    const filtreTexte = this.form.value.recherche?.toLowerCase() || '';
    const filtreType = this.form.value.type || '';
    
    this.journauxFiltres = this.journaux.filter(journal => {
      const matchTexte = !filtreTexte || 
        journal.action.toLowerCase().includes(filtreTexte) ||
        journal.details.toLowerCase().includes(filtreTexte) ||
        journal.utilisateur.toLowerCase().includes(filtreTexte);
      
      const matchType = !filtreType || journal.type === filtreType;
      
      return matchTexte && matchType;
    });
  }

  getDonneesDemonstration(): Journal[] {
    return [
      {
        id: 1,
        date: '2026-04-23 14:30',
        utilisateur: 'Dr. Martin',
        action: 'Création patient',
        details: 'Patient DOE John créé avec dossier WARMS-000001',
        type: 'patient',
        icone: 'person_add'
      },
      {
        id: 2,
        date: '2026-04-23 14:25',
        utilisateur: 'Dr. Martin',
        action: 'Modification consultation',
        details: 'Consultation du patient Smith modifiée',
        type: 'consultation',
        icone: 'edit'
      },
      {
        id: 3,
        date: '2026-04-23 14:20',
        utilisateur: 'Secrétaire',
        action: 'Création rendez-vous',
        details: 'Rendez-vous créé pour patient Dupont',
        type: 'rendez_vous',
        icone: 'calendar_today'
      },
      {
        id: 4,
        date: '2026-04-23 14:15',
        utilisateur: 'Dr. Martin',
        action: 'Connexion',
        details: 'Connexion au système',
        type: 'systeme',
        icone: 'login'
      }
    ];
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

  voirDetails(journal: Journal): void {
    console.log('Détails du journal:', journal);
  }
}
