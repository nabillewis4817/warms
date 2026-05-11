import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { PersonnelService, Personnel, PersonnelFilters, Role, Service, Specialite } from '../noyau/services/personnel.service';
import { AlerteService } from '../noyau/services/alerte.service';

@Component({
  selector: 'app-personnel',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './personnel.component.html',
  styleUrl: './personnel.component.scss'
})
export class PersonnelComponent implements OnInit {
  form: any;
  formulaireAjout: any;
  personnel: Personnel[] = [];
  personnelFiltre: Personnel[] = [];
  chargement = false;
  filtre = '';
  roles: string[] = [];
  services: string[] = [];
  specialites: string[] = [];
  
  // États pour l'ajout/modification
  afficherFormulaireAjout = false;
  modeEdition = false;
  personnelSelectionne: Personnel | null = null;

  constructor(
    private fb: FormBuilder,
    private router: Router,
    private personnelService: PersonnelService,
    private alerteService: AlerteService
  ) {
    this.form = this.fb.group({
      recherche: [''],
      role: [''],
      statut: [''],
      service: ['']
    });

    this.formulaireAjout = this.fb.group({
      prenom: ['', [Validators.required]],
      nom: ['', [Validators.required]],
      email: ['', [Validators.required, Validators.email]],
      telephone: ['', [Validators.required]],
      role: ['', [Validators.required]],
      service: [''],
      specialite: [''],
      date_embauche: [''],
      statut: ['actif', [Validators.required]]
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
        // Exclure les patients: onglet dédié au personnel.
        this.personnel = data.filter((person) => person.role?.toLowerCase() !== 'patient');
        this.personnelFiltre = this.personnel;
        this.chargement = false;
      },
      error: (error) => {
        console.error('Erreur lors du chargement du personnel:', error);
        this.personnel = [];
        this.personnelFiltre = [];
        this.chargement = false;
      }
    });
  }

  chargerOptions(): void {
    // Charger les rôles, services et spécialités disponibles
    this.personnelService.getRoles().subscribe({
      next: (data: Role[]) => {
        this.roles = data.map(item => item.id);
      },
      error: () => {
        this.roles = ['chirurgien_dentiste', 'secretaire', 'infirmiere'];
      }
    });

    this.personnelService.getServices().subscribe({
      next: (data: Service[]) => {
        // Extraire les noms des objets
        this.services = data.map(item => item.nom);
      },
      error: () => {
        this.services = ['Chirurgie générale', 'Orthodontie', 'Pédiatrie', 'Administration'];
      }
    });

    this.personnelService.getSpecialites().subscribe({
      next: (data: Specialite[]) => {
        // Extraire les noms des objets
        this.specialites = data.map(item => item.nom);
      },
      error: () => {
        this.specialites = ['Odontologie générale', 'Chirurgie orale', 'Orthodontie', 'Parodontologie'];
      }
    });
  }

  // Supprimé : getDonneesDemonstration() - Utilisation des vraies données PostgreSQL

  filtrerPersonnel(): void {
    const terme = this.form.get('recherche')?.value?.toLowerCase() || '';
    const role = this.form.get('role')?.value || '';
    const statut = this.form.get('statut')?.value || '';
    const service = this.form.get('service')?.value || '';

    this.personnelFiltre = this.personnel.filter(person => {
      const matchRecherche = !terme || 
        person.prenom.toLowerCase().includes(terme) ||
        person.nom.toLowerCase().includes(terme) ||
        person.email.toLowerCase().includes(terme);
      
      const matchRole = !role || person.role === role;
      const matchStatut = !statut || person.statut === statut;
      const matchService = !service || person.service === service;

      return matchRecherche && matchRole && matchStatut && matchService;
    });
  }

  ajouterPersonnel(): void {
    this.modeEdition = false;
    this.personnelSelectionne = null;
    this.formulaireAjout.reset({
      prenom: '',
      nom: '',
      email: '',
      telephone: '',
      role: '',
      service: '',
      specialite: '',
      date_embauche: '',
      statut: 'actif'
    });
    this.afficherFormulaireAjout = true;
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

  fermerFormulaire(): void {
    this.afficherFormulaireAjout = false;
    this.modeEdition = false;
    this.personnelSelectionne = null;
    this.formulaireAjout.reset();
  }

  enregistrerPersonnel(): void {
    if (this.formulaireAjout.invalid) {
      this.formulaireAjout.markAllAsTouched();
      const champsErreurs = Object.keys(this.formulaireAjout.controls)
        .filter(key => this.formulaireAjout.get(key)?.invalid)
        .map(key => {
          const control = this.formulaireAjout.get(key);
          return this.getNomChamp(key);
        });
      
      this.alerteService.afficherErreurValidation(champsErreurs);
      return;
    }

    const donnees = this.formulaireAjout.value;

    if (this.modeEdition && this.personnelSelectionne) {
      // Mode édition
      this.personnelService.mettreAJourPersonnel(this.personnelSelectionne.id, donnees).subscribe({
        next: () => {
          this.fermerFormulaire();
          this.chargerPersonnel();
          this.alerteService.afficherSuccess('Personnel modifié avec succès');
        },
        error: (error) => {
          console.error('Erreur lors de la modification:', error);
          this.alerteService.afficherErreurTechnique('Impossible de modifier le personnel', error);
        }
      });
    } else {
      // Mode ajout
      this.personnelService.creerPersonnel(donnees).subscribe({
        next: () => {
          this.fermerFormulaire();
          this.chargerPersonnel();
          this.alerteService.afficherSuccess('Personnel ajouté avec succès');
        },
        error: (error) => {
          console.error('Erreur lors de l\'ajout:', error);
          if (error.status === 401) {
            this.alerteService.afficherPermissionRefusee('secrétaire', 'créer ce type de personnel');
          } else if (error.status === 403) {
            this.alerteService.afficherPermissionInsuffise('secrétaire', 'chirurgien-dentiste', 'créer un chirurgien-dentiste');
          } else {
            this.alerteService.afficherErreurTechnique('Impossible d\'ajouter le personnel', error);
          }
        }
      });
    }
  }

  private getNomChamp(key: string): string {
    const noms: { [key: string]: string } = {
      'prenom': 'Prénom',
      'nom': 'Nom',
      'email': 'Email',
      'telephone': 'Téléphone',
      'role': 'Rôle',
      'service': 'Service',
      'specialite': 'Spécialité',
      'date_embauche': 'Date d\'embauche',
      'statut': 'Statut'
    };
    return noms[key] || key;
  }

  formatDate(dateString: string): string {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: 'numeric',
      month: 'long',
      year: 'numeric'
    });
  }

  getRoleLabel(role: string): string {
    const labels: { [key: string]: string } = {
      'chirurgien_dentiste': 'Chirurgien Dentiste',
      'secretaire': 'Secrétaire',
      'infirmiere': 'Infirmière',
      'assistant': 'Assistant',
      'admin': 'Administrateur',
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
      'actif': '#22c55e',
      'inactif': '#ef4444',
      'conge': '#f59e0b',
      'suspendu': '#6b7280'
    };
    return colors[statut] || '#6b7280';
  }

  getInitialesPersonnel(person: any): string {
    if (!person.prenom && !person.nom) return '?';
    const prenom = person.prenom || '';
    const nom = person.nom || '';
    return (prenom.charAt(0) + nom.charAt(0)).toUpperCase();
  }

  getRoleIcon(role: string): string {
    const icons: { [key: string]: string } = {
      // Rôles dentaires
      'chirurgien_dentiste': '/assets/dentist.png',
      'chirurgien-dentiste': '/assets/dentist.png',
      'dentist': '/assets/dentist.png',
      'chirurgien dentiste': '/assets/dentist.png',
      'dentiste': '/assets/dentist.png',
      'assistant dentaire': '/assets/nurse.png',
      'orthodontiste': '/assets/dentist.png',
      'parodontiste': '/assets/dentist.png',
      'radiologue': '/assets/medical.png',
      
      // Rôles médicaux
      'infirmiere': '/assets/nurse.png',
      'infirmière': '/assets/nurse.png',
      'nurse': '/assets/nurse.png',
      'medecin': '/assets/medical.png',
      'médecin': '/assets/medical.png',
      'doctor': '/assets/medical.png',
      
      // Rôles administratifs
      'secrétaire': '/assets/secretary.png',
      'secretary': '/assets/secretary.png',
      'administrateur': '/assets/secretary.png',
      'admin': '/assets/secretary.png',
      'gestionnaire': '/assets/secretary.png',
      
      // Rôles de service
      'cuisinier': '/assets/cleaner.png',
      'vigile': '/assets/cleaner.png',
      'technicien de surface': '/assets/cleaner.png',
      'cleaner': '/assets/cleaner.png',
      'agent de service': '/assets/cleaner.png',
      'maintenance': '/assets/cleaner.png',
      
      // Patients
      'patient': '/assets/patient.png',
      'patients': '/assets/patient.png',
      'client': '/assets/patient.png'
    };
    
    // Normaliser le rôle pour la recherche (insensible à la casse et aux accents)
    const normalizedRole = role.toLowerCase().trim();
    
    // Chercher d'abord une correspondance exacte
    if (icons[normalizedRole]) {
      return icons[normalizedRole];
    }
    
    // Chercher une correspondance partielle
    for (const [key, value] of Object.entries(icons)) {
      if (normalizedRole.includes(key) || key.includes(normalizedRole)) {
        return value;
      }
    }
    
    // Debug: afficher le rôle et la recherche si pas trouvé
    console.log(`Rôle non trouvé: "${role}" (normalisé: "${normalizedRole}")`);
    console.log('Rôles disponibles:', Object.keys(icons));
    
    // Valeur par défaut
    return '/assets/default-avatar.png';
  }
}
