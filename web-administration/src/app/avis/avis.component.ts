import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';

@Component({
  selector: 'app-avis',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './avis.component.html',
  styleUrl: './avis.component.scss'
})
export class AvisComponent implements OnInit {
  form: any;
  avis: any[] = [];
  chargement = false;
  filtre = '';
  statistiques = {
    moyenne: 0,
    total: 0,
    note5: 0,
    note4: 0,
    note3: 0,
    note2: 0,
    note1: 0
  };

  constructor(
    private fb: FormBuilder,
    private router: Router
  ) {
    this.form = this.fb.group({
      recherche: [''],
      dateDebut: [''],
      dateFin: [''],
      noteMin: [''],
      noteMax: [''],
      patient: ['']
    });
  }

  ngOnInit(): void {
    this.chargerAvis();
  }

  chargerAvis(): void {
    this.chargement = true;
    // Simulation de données - à remplacer avec appel API réel
    setTimeout(() => {
      this.avis = [
        {
          id: 1,
          patient: 'John DOE',
          date: '2026-04-23',
          note: 5,
          commentaire: 'Excellent service, personnel très compétent et accueillant. Cabinet moderne et propre.',
          type: 'consultation',
          praticien: 'Dr. Martin'
        },
        {
          id: 2,
          patient: 'Marie DURAND',
          date: '2026-04-22',
          note: 4,
          commentaire: 'Bonne consultation mais temps d\'attente un peu long. Installation dentaire bien expliquée.',
          type: 'traitement',
          praticien: 'Dr. Martin'
        },
        {
          id: 3,
          patient: 'Pierre DUPONT',
          date: '2026-04-21',
          note: 5,
          commentaire: 'Très satisfait du détartrage. Professionnalisme remarquable.',
          type: 'soin',
          praticien: 'Dr. Sophie'
        },
        {
          id: 4,
          patient: 'Sophie LEROY',
          date: '2026-04-20',
          note: 3,
          commentaire: 'Consultation correcte mais pourrait améliorer l\'accueil.',
          type: 'consultation',
          praticien: 'Dr. Martin'
        },
        {
          id: 5,
          patient: 'Jean PETIT',
          date: '2026-04-19',
          note: 5,
          commentaire: 'Extraction dentaire sans douleur. Chirurgien très expérimenté.',
          type: 'chirurgie',
          praticien: 'Dr. Thomas'
        }
      ];
      
      this.calculerStatistiques();
      this.chargement = false;
    }, 1000);
  }

  calculerStatistiques(): void {
    if (this.avis.length === 0) return;
    
    const notes = this.avis.map(a => a.note);
    this.statistiques.moyenne = parseFloat((notes.reduce((a, b) => a + b, 0) / notes.length).toFixed(1));
    this.statistiques.total = this.avis.length;
    this.statistiques.note5 = notes.filter(n => n === 5).length;
    this.statistiques.note4 = notes.filter(n => n === 4).length;
    this.statistiques.note3 = notes.filter(n => n === 3).length;
    this.statistiques.note2 = notes.filter(n => n === 2).length;
    this.statistiques.note1 = notes.filter(n => n === 1).length;
  }

  filtrerAvis(): void {
    this.filtre = this.form.value.recherche?.toLowerCase() || '';
  }

  get avisFiltres(): any[] {
    if (!this.filtre) return this.avis;
    
    return this.avis.filter(avi => 
      avi.patient.toLowerCase().includes(this.filtre) ||
      avi.commentaire.toLowerCase().includes(this.filtre) ||
      avi.praticien.toLowerCase().includes(this.filtre)
    );
  }

  voirDetails(avi: any): void {
    // Navigation vers les détails de l'avis
    console.log('Voir détails:', avi);
  }

  exporterAvis(): void {
    // Fonctionnalité d'exportation
    console.log('Exporter les avis');
  }

  rafraichir(): void {
    this.chargerAvis();
  }

  getEtoiles(note: number): string {
    let etoiles = '';
    for (let i = 1; i <= 5; i++) {
      etoiles += i <= note ? '★' : '☆';
    }
    return etoiles;
  }

  getStatistiquesNote(note: number): { count: number, percentage: string } {
    let count = 0;
    switch(note) {
      case 5: count = this.statistiques.note5; break;
      case 4: count = this.statistiques.note4; break;
      case 3: count = this.statistiques.note3; break;
      case 2: count = this.statistiques.note2; break;
      case 1: count = this.statistiques.note1; break;
    }
    const percentage = this.statistiques.total > 0 ? ((count / this.statistiques.total) * 100).toFixed(1) : '0';
    return { count, percentage };
  }

  getTypeAvis(type: string): string {
    const types: { [key: string]: string } = {
      'consultation': 'Consultation',
      'traitement': 'Traitement',
      'soin': 'Soin',
      'chirurgie': 'Chirurgie',
      'examen': 'Examen'
    };
    return types[type] || type;
  }
}
