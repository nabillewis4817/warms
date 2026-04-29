import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { PersonnelService, Personnel, PersonnelFilters } from '../noyau/services/personnel.service';

@Component({
  selector: 'app-personnel',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './personnel.component.html',
  styleUrl: './personnel.component.scss'
})
export class PersonnelComponent implements OnInit {
  form: any;
  personnel: Personnel[] = [];
  personnelFiltre: Personnel[] = [];
  chargement = false;
  filtre = '';
  roles: string[] = [];
  services: string[] = [];
  specialites: string[] = [];

  constructor(
    private fb: FormBuilder,
    private router: Router,
    private personnelService: PersonnelService
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
    this.chargerOptions();
  }

  chargerPersonnel(): void {
    this.chargement = true;
    const filters: PersonnelFilters = this.form.value;
    
    this.personnelService.getPersonnel(filters).subscribe({
      next: (data) => {
        this.personnel = data;
        this.personnelFiltre = data;
        this.chargement = false;
      },
      error: (error) => {
        console.error('Erreur lors du chargement du personnel:', error);
        this.chargement = false;
        // En cas d'erreur, utiliser des données de démonstration
        this.personnel = this.getDonneesDemonstration();
        this.personnelFiltre = this.personnel;
      }
    });
  }

  chargerOptions(): void {
    // Charger les rôles, services et spécialités disponibles
    this.personnelService.getRoles().subscribe({
      next: (data) => {
        this.roles = data;
      },
      error: () => {
        this.roles = ['chirurgien_dentiste', 'secretaire', 'infirmiere', 'patient'];
      }
    });

    this.personnelService.getServices().subscribe({
      next: (data) => {
        this.services = data;
      },
      error: () => {
        this.services = ['Chirurgie générale', 'Orthodontie', 'Pédiatrie', 'Administration'];
      }
    });

    this.personnelService.getSpecialites().subscribe({
      next: (data) => {
        this.specialites = data;
      },
      error: () => {
        this.specialites = ['Implantologie', 'Orthodontie', 'Pédiatrie', 'Parodontologie'];
      }
    });
  }

  getDonneesDemonstration(): Personnel[] {
    return [
      {
        id: 1,
        nom: 'Martin',
        prenom: 'Jean',
        email: 'jean.martin@warms.com',
        telephone: '+237123456789',
        role: 'chirurgien_dentiste',
        statut: 'actif',
        date_embauche: '2020-01-15',
        service: 'Chirurgie générale',
        specialite: 'Implantologie',
        photo: undefined
      },
      {
        id: 2,
        nom: 'Durand',
        prenom: 'Sophie',
        email: 'sophie.durand@warms.com',
        telephone: '+237987654321',
        role: 'secretaire',
        statut: 'actif',
        date_embauche: '2019-03-20',
        service: 'Administration',
        specialite: undefined,
        photo: undefined
      },
      {
        id: 3,
        nom: 'Lefebvre',
        prenom: 'Marie',
        email: 'marie.lefebvre@warms.com',
        telephone: '+237654321987',
        role: 'infirmiere',
        statut: 'actif',
        date_embauche: '2021-06-10',
        service: 'Chirurgie générale',
        specialite: 'Assistance chirurgicale',
        photo: undefined
      }
    ];
  }

  filtrerPersonnel(): void {
    const filtreTexte = this.form.value.recherche?.toLowerCase() || '';
    const filtreRole = this.form.value.role || '';
    const filtreStatut = this.form.value.statut || '';
    const filtreService = this.form.value.service || '';
    
    this.personnelFiltre = this.personnel.filter(person => {
      const matchTexte = !filtreTexte || 
        person.nom.toLowerCase().includes(filtreTexte) ||
        person.prenom.toLowerCase().includes(filtreTexte) ||
        person.email.toLowerCase().includes(filtreTexte);
      
      const matchRole = !filtreRole || person.role === filtreRole;
      const matchStatut = !filtreStatut || person.statut === filtreStatut;
      const matchService = !filtreService || person.service === filtreService;
      
      return matchTexte && matchRole && matchStatut && matchService;
    });
  }

  ajouterPersonnel(): void {
    // Navigation vers le formulaire d'ajout
    this.router.navigate(['/personnel/nouveau']);
  }

  modifierPersonnel(person: Personnel): void {
    // Navigation vers le formulaire de modification
    this.router.navigate(['/personnel/modifier', person.id]);
  }

  supprimerPersonnel(person: Personnel): void {
    if (confirm(`Êtes-vous sûr de vouloir supprimer ${person.prenom} ${person.nom} ?`)) {
      this.personnelService.supprimerPersonnel(person.id).subscribe({
        next: () => {
          this.chargerPersonnel();
        },
        error: (error) => {
          console.error('Erreur lors de la suppression:', error);
          alert('Erreur lors de la suppression du personnel');
        }
      });
    }
  }

  voirDetails(person: Personnel): void {
    console.log('Détails du personnel:', person);
  }

  exporterPersonnel(): void {
    const filters: PersonnelFilters = this.form.value;
    
    this.personnelService.exporterPersonnel(filters).subscribe({
      next: (blob) => {
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `personnel_${new Date().toISOString().split('T')[0]}.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        window.URL.revokeObjectURL(url);
      },
      error: (error) => {
        console.error('Erreur lors de l\'exportation du personnel:', error);
        alert('Erreur lors de l\'exportation du personnel');
      }
    });
  }

  getRoleLabel(role: string): string {
    const labels: { [key: string]: string } = {
      'chirurgien_dentiste': 'Chirurgien Dentiste',
      'secretaire': 'Secrétaire',
      'infirmiere': 'Infirmière',
      'patient': 'Patient'
    };
    return labels[role] || role;
  }

  getStatutBadge(statut: string): string {
    const badges: { [key: string]: string } = {
      'actif': 'Actif',
      'inactif': 'Inactif',
      'en_conge': 'En congé',
      'suspendu': 'Suspendu'
    };
    return badges[statut] || statut;
  }

  getStatutColor(statut: string): string {
    const colors: { [key: string]: string } = {
      'actif': '#28a745',
      'inactif': '#6c757d',
      'en_conge': '#ffc107',
      'suspendu': '#dc3545'
    };
    return colors[statut] || '#6c757d';
  }
}
