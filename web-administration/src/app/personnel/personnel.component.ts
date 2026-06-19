import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { PersonnelService, Personnel, PersonnelFilters, Role, Service, Specialite } from '../noyau/services/personnel.service';
import { AlerteService } from '../noyau/services/alerte.service';
import { CapturePhoto } from '../noyau/composants/capture-photo/capture-photo';

@Component({
  selector: 'app-personnel',
  imports: [CommonModule, ReactiveFormsModule, CapturePhoto],
  templateUrl: './personnel.component.html',
  styleUrl: './personnel.component.scss'
})
export class PersonnelComponent implements OnInit {
  form: any;
  formulaireAjout: any;
  personnel: Personnel[] = [];
  personnelFiltre: Personnel[] = [];
  chargement = false;
  roles: string[] = [];
  services: string[] = [];
  specialites: string[] = [];

  // États pour l'ajout/modification
  afficherFormulaireAjout = false;
  modeEdition = false;
  personnelSelectionne: Personnel | null = null;
  enregistrementEnCours = false;
  photoFichier: File | null = null;
  photoSupprimee = false;

  // Détail
  detailOuvert = false;
  detailChargement = false;
  personnelDetail: Personnel | null = null;

  // Suppression
  personnelASupprimer: Personnel | null = null;

  constructor(
    private fb: FormBuilder,
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

  // ===== Chargement =====

  chargerPersonnel(): void {
    this.chargement = true;
    const filters: PersonnelFilters = this.form.value;

    this.personnelService.getPersonnel(filters).subscribe({
      next: (data) => {
        this.personnel = data.filter((person) => person.role?.toLowerCase() !== 'patient');
        this.filtrerPersonnel();
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
    this.personnelService.getRoles().subscribe({
      next: (data: Role[]) => { this.roles = data.map(item => item.id); },
      error: () => { this.roles = ['chirurgien_dentiste', 'secretaire', 'infirmiere', 'assistant', 'admin']; }
    });

    this.personnelService.getServices().subscribe({
      next: (data: Service[]) => { this.services = data.map(item => item.nom); },
      error: () => { this.services = ['Chirurgie générale', 'Orthodontie', 'Pédiatrie', 'Administration']; }
    });

    this.personnelService.getSpecialites().subscribe({
      next: (data: Specialite[]) => { this.specialites = data.map(item => item.nom); },
      error: () => { this.specialites = ['Odontologie générale', 'Chirurgie orale', 'Orthodontie', 'Parodontologie']; }
    });
  }

  // ===== Statistiques =====

  get totalPersonnel(): number { return this.personnel.length; }
  get totalActifs(): number { return this.personnel.filter(p => p.statut === 'actif').length; }
  get totalEnConge(): number { return this.personnel.filter(p => p.statut === 'conge').length; }
  get totalIndisponibles(): number {
    return this.personnel.filter(p => p.statut === 'suspendu' || p.statut === 'inactif').length;
  }
  get nombreRoles(): number { return new Set(this.personnel.map(p => p.role)).size; }

  // ===== Filtrage =====

  filtrerPersonnel(): void {
    const terme = (this.form.get('recherche')?.value ?? '').toLowerCase();
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

  reinitialiserFiltres(): void {
    this.form.reset({ recherche: '', role: '', statut: '', service: '' });
    this.filtrerPersonnel();
  }

  get filtresActifs(): boolean {
    const v = this.form.value;
    return !!(v.recherche || v.role || v.statut || v.service);
  }

  // ===== Ajout / Modification =====

  ajouterPersonnel(): void {
    this.modeEdition = false;
    this.personnelSelectionne = null;
    this.photoFichier = null;
    this.photoSupprimee = false;
    this.formulaireAjout.reset({
      prenom: '', nom: '', email: '', telephone: '', role: '',
      service: '', specialite: '', date_embauche: '', statut: 'actif'
    });
    this.afficherFormulaireAjout = true;
  }

  modifierPersonnel(person: Personnel): void {
    this.detailOuvert = false;
    this.modeEdition = true;
    this.personnelSelectionne = person;
    this.photoFichier = null;
    this.photoSupprimee = false;
    this.formulaireAjout.reset({
      prenom: person.prenom,
      nom: person.nom,
      email: person.email,
      telephone: person.telephone,
      role: person.role,
      service: person.service ?? '',
      specialite: person.specialite ?? '',
      date_embauche: person.date_embauche ?? '',
      statut: person.statut || 'actif'
    });
    this.afficherFormulaireAjout = true;
  }

  onPhotoChange(fichier: File | null): void {
    this.photoFichier = fichier;
    this.photoSupprimee = !fichier;
  }

  fermerFormulaire(): void {
    this.afficherFormulaireAjout = false;
    this.modeEdition = false;
    this.personnelSelectionne = null;
    this.photoFichier = null;
    this.formulaireAjout.reset();
  }

  enregistrerPersonnel(): void {
    if (this.formulaireAjout.invalid) {
      this.formulaireAjout.markAllAsTouched();
      const champsErreurs = Object.keys(this.formulaireAjout.controls)
        .filter(key => this.formulaireAjout.get(key)?.invalid)
        .map(key => this.getNomChamp(key));

      this.alerteService.afficherErreurValidation(champsErreurs);
      return;
    }

    const donnees = this.formulaireAjout.value;
    this.enregistrementEnCours = true;

    if (this.modeEdition && this.personnelSelectionne) {
      this.personnelService.mettreAJourPersonnel(this.personnelSelectionne.id, donnees, this.photoFichier).subscribe({
        next: () => {
          this.enregistrementEnCours = false;
          this.fermerFormulaire();
          this.chargerPersonnel();
          this.alerteService.afficherSuccess('Personnel modifié avec succès');
        },
        error: (error) => {
          this.enregistrementEnCours = false;
          console.error('Erreur lors de la modification:', error);
          this.alerteService.afficherErreurTechnique('Impossible de modifier le personnel', error);
        }
      });
    } else {
      this.personnelService.creerPersonnel(donnees, this.photoFichier).subscribe({
        next: () => {
          this.enregistrementEnCours = false;
          this.fermerFormulaire();
          this.chargerPersonnel();
          this.alerteService.afficherSuccess('Personnel ajouté avec succès');
        },
        error: (error) => {
          this.enregistrementEnCours = false;
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

  // ===== Suppression =====

  demanderSuppression(person: Personnel): void {
    this.detailOuvert = false;
    this.personnelASupprimer = person;
  }

  annulerSuppression(): void {
    this.personnelASupprimer = null;
  }

  confirmerSuppression(): void {
    if (!this.personnelASupprimer) return;
    const person = this.personnelASupprimer;
    this.personnelService.supprimerPersonnel(person.id).subscribe({
      next: () => {
        this.personnelASupprimer = null;
        this.chargerPersonnel();
        this.alerteService.afficherSuccess(`${person.prenom} ${person.nom} a été supprimé(e)`);
      },
      error: (error) => {
        console.error('Erreur lors de la suppression:', error);
        this.personnelASupprimer = null;
        this.alerteService.afficherErreurTechnique('Impossible de supprimer le personnel', error);
      }
    });
  }

  // ===== Détails =====

  voirDetails(person: Personnel): void {
    this.detailOuvert = true;
    this.detailChargement = true;
    this.personnelDetail = person;
    this.personnelService.obtenirDetail(person.id).subscribe({
      next: (detail) => {
        this.personnelDetail = detail;
        this.detailChargement = false;
      },
      error: () => { this.detailChargement = false; },
    });
  }

  fermerDetails(): void {
    this.detailOuvert = false;
    this.personnelDetail = null;
  }

  changerStatutRapide(person: Personnel, statut: string): void {
    this.personnelService.changerStatut(person.id, statut).subscribe({
      next: (maj) => {
        if (this.personnelDetail?.id === person.id) this.personnelDetail = maj;
        this.chargerPersonnel();
        this.alerteService.afficherSuccess(`Statut mis à jour : ${this.getStatutBadge(statut)}`);
      },
      error: (error) => {
        this.alerteService.afficherErreurTechnique('Impossible de changer le statut', error);
      }
    });
  }

  // ===== Export =====

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
        this.alerteService.afficherErreurTechnique("Impossible d'exporter le personnel", error);
      }
    });
  }

  // ===== Helpers d'affichage =====

  private getNomChamp(key: string): string {
    const noms: { [key: string]: string } = {
      prenom: 'Prénom', nom: 'Nom', email: 'Email', telephone: 'Téléphone',
      role: 'Rôle', service: 'Service', specialite: 'Spécialité',
      date_embauche: "Date d'embauche", statut: 'Statut'
    };
    return noms[key] || key;
  }

  formatDate(dateString?: string): string {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  }

  getRoleLabel(role: string): string {
    const labels: { [key: string]: string } = {
      chirurgien_dentiste: 'Chirurgien Dentiste',
      secretaire: 'Secrétaire',
      infirmiere: 'Infirmière',
      assistant: 'Assistant',
      admin: 'Administrateur',
      patient: 'Patient'
    };
    return labels[role] || role;
  }

  getStatutBadge(statut: string): string {
    const badges: { [key: string]: string } = {
      actif: 'Actif', inactif: 'Inactif', conge: 'En congé', suspendu: 'Suspendu'
    };
    return badges[statut] || statut;
  }

  getStatutColor(statut: string): string {
    const colors: { [key: string]: string } = {
      actif: '#22c55e', inactif: '#ef4444', conge: '#f59e0b', suspendu: '#6b7280'
    };
    return colors[statut] || '#6b7280';
  }

  getInitialesPersonnel(person: { prenom?: string; nom?: string }): string {
    if (!person.prenom && !person.nom) return '?';
    const prenom = person.prenom || '';
    const nom = person.nom || '';
    return (prenom.charAt(0) + nom.charAt(0)).toUpperCase();
  }

  getRoleIcon(role: string): string {
    const icons: { [key: string]: string } = {
      chirurgien_dentiste: '/assets/dentist.png',
      'chirurgien-dentiste': '/assets/dentist.png',
      dentist: '/assets/dentist.png',
      'chirurgien dentiste': '/assets/dentist.png',
      dentiste: '/assets/dentist.png',
      'assistant dentaire': '/assets/nurse.png',
      assistant: '/assets/nurse.png',
      orthodontiste: '/assets/dentist.png',
      parodontiste: '/assets/dentist.png',
      radiologue: '/assets/medical.png',
      infirmiere: '/assets/nurse.png',
      infirmière: '/assets/nurse.png',
      nurse: '/assets/nurse.png',
      medecin: '/assets/medical.png',
      médecin: '/assets/medical.png',
      doctor: '/assets/medical.png',
      secrétaire: '/assets/secretary.png',
      secretaire: '/assets/secretary.png',
      secretary: '/assets/secretary.png',
      administrateur: '/assets/secretary.png',
      admin: '/assets/secretary.png',
      gestionnaire: '/assets/secretary.png',
      patient: '/assets/patient.png',
    };
    const normalizedRole = (role || '').toLowerCase().trim();
    if (icons[normalizedRole]) return icons[normalizedRole];
    for (const [key, value] of Object.entries(icons)) {
      if (normalizedRole.includes(key) || key.includes(normalizedRole)) return value;
    }
    return '/assets/default-avatar.png';
  }
}
