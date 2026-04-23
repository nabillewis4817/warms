import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';

@Component({
  selector: 'app-personnel',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './personnel.component.html',
  styleUrl: './personnel.component.scss'
})
export class PersonnelComponent implements OnInit {
  form: any;
  personnel: any[] = [];
  chargement = false;
  filtre = '';
  roles = ['chirurgien_dentiste', 'secretaire', 'infirmiere', 'patient'];

  constructor(
    private fb: FormBuilder,
    private router: Router
  ) {
    this.form = this.fb.group({
      recherche: [''],
      role: [''],
      statut: [''],
      service: ['']
    });
  }

  ngOnInit(): void {
    this.chargerPersonnel();
  }

  chargerPersonnel(): void {
    this.chargement = true;
    // Simulation de données - à remplacer avec appel API réel
    setTimeout(() => {
      this.personnel = [
        {
          id: 1,
          nom: 'Dr. Martin',
          prenom: 'Jean',
          email: 'jean.martin@warms.com',
          telephone: '+237123456789',
          role: 'chirurgien_dentiste',
          statut: 'actif',
          dateEmbauche: '2020-01-15',
          service: 'Chirurgie générale',
          specialite: 'Implantologie',
          photo: null
        },
        {
          id: 2,
          nom: 'Durand',
          prenom: 'Sophie',
          email: 'sophie.durand@warms.com',
          telephone: '+237987654321',
          role: 'secretaire',
          statut: 'actif',
          dateEmbauche: '2021-03-10',
          service: 'Accueil et gestion',
          specialite: null,
          photo: null
        },
        {
          id: 3,
          nom: 'Petit',
          prenom: 'Marie',
          email: 'marie.petit@warms.com',
          telephone: '+237654321987',
          role: 'infirmiere',
          statut: 'actif',
          dateEmbauche: '2022-06-01',
          service: 'Assistance chirurgicale',
          specialite: 'Stérilisation',
          photo: null
        },
        {
          id: 4,
          nom: 'Bernard',
          prenom: 'Pierre',
          email: 'pierre.bernard@warms.com',
          telephone: '+237456789012',
          role: 'chirurgien_dentiste',
          statut: 'en_conge',
          dateEmbauche: '2019-09-20',
          service: 'Orthodontie',
          specialite: 'Appareillage orthodontique',
          photo: null
        }
      ];
      this.chargement = false;
    }, 1000);
  }

  filtrerPersonnel(): void {
    this.filtre = this.form.value.recherche?.toLowerCase() || '';
  }

  get personnelFiltre(): any[] {
    if (!this.filtre) return this.personnel;
    
    return this.personnel.filter(person => 
      person.nom.toLowerCase().includes(this.filtre) ||
      person.prenom.toLowerCase().includes(this.filtre) ||
      person.email.toLowerCase().includes(this.filtre) ||
      person.role.toLowerCase().includes(this.filtre)
    );
  }

  voirDetails(person: any): void {
    // Navigation vers les détails du personnel
    console.log('Voir détails:', person);
  }

  ajouterPersonnel(): void {
    // Navigation vers le formulaire d'ajout
    this.router.navigate(['/personnel', 'ajouter']);
  }

  modifierPersonnel(person: any): void {
    // Navigation vers le formulaire de modification
    this.router.navigate(['/personnel', person.id, 'modifier']);
  }

  supprimerPersonnel(person: any): void {
    // Confirmation et suppression
    if (confirm(`Êtes-vous sûr de vouloir supprimer ${person.prenom} ${person.nom} ?`)) {
      console.log('Supprimer:', person);
      // Ici, appeler l'API pour supprimer
    }
  }

  getRoleLabel(role: string): string {
    const labels: { [key: string]: string } = {
      'chirurgien_dentiste': 'Chirurgien-Dentiste',
      'secretaire': 'Secrétaire',
      'infirmiere': 'Infirmière',
      'patient': 'Patient'
    };
    return labels[role] || role;
  }

  getStatutBadge(statut: string): string {
    const badges: { [key: string]: string } = {
      'actif': 'Actif',
      'en_conge': 'En congé',
      'en_maladie': 'En maladie',
      'en_formation': 'En formation'
    };
    return badges[statut] || statut;
  }

  getStatutColor(statut: string): string {
    const colors: { [key: string]: string } = {
      'actif': '#10b981',
      'en_conge': '#f59e0b',
      'en_maladie': '#ef4444',
      'en_formation': '#3b82f6'
    };
    return colors[statut] || '#64748b';
  }
}
