import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';

@Component({
  selector: 'app-journaux',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './journaux.component.html',
  styleUrl: './journaux.component.scss'
})
export class JournauxComponent implements OnInit {
  form: any;
  journaux: any[] = [];
  chargement = false;
  filtre = '';

  constructor(
    private fb: FormBuilder,
    private router: Router
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
    // Simulation de données - à remplacer avec appel API réel
    setTimeout(() => {
      this.journaux = [
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
      this.chargement = false;
    }, 1000);
  }

  filtrerJournaux(): void {
    this.filtre = this.form.value.recherche?.toLowerCase() || '';
  }

  get journauxFiltres(): any[] {
    if (!this.filtre) return this.journaux;
    
    return this.journaux.filter(journal => 
      journal.action.toLowerCase().includes(this.filtre) ||
      journal.details.toLowerCase().includes(this.filtre) ||
      journal.utilisateur.toLowerCase().includes(this.filtre)
    );
  }

  voirDetails(journal: any): void {
    // Navigation vers les détails du journal
    console.log('Voir détails:', journal);
  }

  exporterJournaux(): void {
    // Fonctionnalité d'exportation
    console.log('Exporter les journaux');
  }

  rafraichir(): void {
    this.chargerJournaux();
  }

  getIcone(type: string): string {
    const icones: { [key: string]: string } = {
      'patient': '👤',
      'consultation': '📋',
      'rendez_vous': '📅',
      'systeme': '⚙️',
      'personnel': '👥',
      'message': '💬',
      'document': '📄'
    };
    return icones[type] || '📋';
  }
}
