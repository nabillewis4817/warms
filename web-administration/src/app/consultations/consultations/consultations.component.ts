import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, ViewChild, ElementRef } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';
import { FormBuilder, FormGroup, ReactiveFormsModule, FormsModule, Validators } from '@angular/forms';
import { Subject, debounceTime, distinctUntilChanged } from 'rxjs';

import { ConsultationsService, Consultation, ActeRealise, PhotoClinique } from '../../noyau/services/consultations.service';
import { DialogueService } from '../../noyau/services/dialogue.service';
import { Patients, Patient } from '../../noyau/services/patients';
import { PersonnelService, Personnel } from '../../noyau/services/personnel.service';
import { RendezVousService, RendezVous } from '../../noyau/services/rendez-vous';

@Component({
  selector: 'app-consultations',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule],
  templateUrl: './consultations.component.html',
  styleUrl: './consultations.component.scss'
})
export class ConsultationsComponent implements OnInit {
  private readonly consultationsService = inject(ConsultationsService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly fb = inject(FormBuilder);
  private readonly dialogueService = inject(DialogueService);
  private readonly patientsService = inject(Patients);
  private readonly personnelService = inject(PersonnelService);
  private readonly rendezVousService = inject(RendezVousService);

  readonly Math = Math;

  consultations: Consultation[] = [];
  consultationSelectionnee: Consultation | null = null;
  actesConsultation: ActeRealise[] = [];
  photosConsultation: PhotoClinique[] = [];
  patients: Patient[] = [];
  praticiens: Personnel[] = [];
  rendezVousList: RendezVous[] = [];
  chargementPatients = false;
  chargementPraticiens = false;
  consultationsChargees = false;

  chargement = false;
  afficherDetails = false;
  afficherFormulaire = false;
  modeEdition = false;
  suppressionEnCours = false;

  // Formulaires
  formulaireConsultation!: FormGroup;
  formulaireActe!: FormGroup;

  // Recherche et pagination
  termeRecherche$ = new Subject<string>();
  pageActuelle = 1;
  taillePage = 10;
  totalElements = 0;

  // Filtres
  filtrePatient: number | null = null;
  filtrePraticien: number | null = null;
  filtreDateDebut: string | null = null;
  filtreDateFin: string | null = null;

  // ViewChild pour les animations
  @ViewChild('modalContent') modalContent!: ElementRef;
  @ViewChild('cardContainer') cardContainer!: ElementRef;

  ngOnInit(): void {
    this.initialiserFormulaires();
    this.configurerRecherche();
    this.chargerPatients();
    this.chargerPraticiens();
    this.chargerRendezVous();
    this.chargerConsultations();
  }

  onPatientChange(patientId: number | null): void {
    if (!patientId) return;
    const patient = this.patients.find((p) => p.id === patientId);
    if (patient?.dossier_id) {
      this.formulaireConsultation.patchValue({ dossier: patient.dossier_id });
    }
  }

  private initialiserFormulaires(): void {
    // Formulaire consultation
    this.formulaireConsultation = this.fb.group({
      patient: [null, Validators.required],
      dossier: [null],
      rendez_vous: [null],
      praticien: [null],
      date: [null, Validators.required],
      motif: ['', Validators.required],
      observations: [''],
      diagnostic: ['', Validators.required],
      notes: ['']
    });

    // Formulaire acte
    this.formulaireActe = this.fb.group({
      libelle: ['', Validators.required],
      description: [''],
      dent: ['']
    });
  }

  private configurerRecherche(): void {
    this.termeRecherche$.pipe(
      debounceTime(300),
      distinctUntilChanged()
    ).subscribe(terme => {
      if (terme) {
        this.rechercherConsultations(terme);
      } else {
        this.chargerConsultations();
      }
    });
  }

  chargerPatients(): void {
    this.chargementPatients = true;
    this.patientsService.lister().subscribe({
      next: (patients) => {
        this.patients = patients;
        this.chargementPatients = false;
      },
      error: (error) => {
        console.error('Erreur lors du chargement des patients:', error);
        this.patients = [];
        this.chargementPatients = false;
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: 'Impossible de charger la liste des patients. Vérifiez la connexion au serveur.',
        });
      },
    });
  }

  chargerPraticiens(): void {
    this.chargementPraticiens = true;
    this.personnelService.getPersonnel().subscribe({
      next: (liste) => {
        this.praticiens = liste.filter(
          (p) => p.statut !== 'inactif' && p.role?.toLowerCase() !== 'patient'
        );
        this.chargementPraticiens = false;
      },
      error: (error) => {
        console.error('Erreur lors du chargement du personnel:', error);
        this.praticiens = [];
        this.chargementPraticiens = false;
      },
    });
  }

  chargerRendezVous(): void {
    this.rendezVousService.lister().subscribe({
      next: (liste) => {
        this.rendezVousList = liste;
      },
      error: () => {
        this.rendezVousList = [];
      },
    });
  }

  libellePraticien(p: Personnel): string {
    const nom = [p.prenom, p.nom].filter(Boolean).join(' ').trim();
    return nom ? `${nom} (${this.libelleRole(p.role)})` : p.email || `Utilisateur #${p.id}`;
  }

  libelleRole(role: string): string {
    const roles: Record<string, string> = {
      chirurgien_dentiste: 'Chirurgien-dentiste',
      secretaire: 'Secrétaire',
      infirmiere: 'Infirmière',
      administrateur: 'Administrateur',
    };
    return roles[role] ?? role;
  }

  libelleRendezVous(rdv: RendezVous): string {
    const patient =
      rdv.patient_prenom && rdv.patient_nom
        ? `${rdv.patient_prenom} ${rdv.patient_nom}`
        : this.patients.find((p) => p.id === rdv.patient)
          ? `${this.patients.find((p) => p.id === rdv.patient)!.prenom} ${this.patients.find((p) => p.id === rdv.patient)!.nom}`
          : `Patient #${rdv.patient}`;
    return `${patient} — ${this.formatDate(rdv.date_heure)}`;
  }

  chargerConsultations(): void {
    this.chargement = true;
    
    const params = this.construireParamsRecherche();
    
    this.consultationsService.getConsultations(params).subscribe({
      next: (consultations) => {
        this.consultations = consultations;
        this.totalElements = consultations.length;
        this.chargement = false;
        this.animerEntreeCards();
      },
      error: (error) => {
        console.error('Erreur lors du chargement des consultations:', error);
        this.consultations = []; // Vider la liste en cas d'erreur
        this.totalElements = 0;
        this.chargement = false;
        
        // Ne pas afficher d'erreur pour le cas où il n'y a pas encore de consultations
        if (error.status !== 404) {
          this.dialogueService.erreur({
            titre: 'Erreur',
            message: 'Impossible de charger les consultations. Veuillez réessayer.'
          });
        }
      }
    });
  }

  // Charger les consultations uniquement sur demande
  chargerConsultationsSurDemande(): void {
    this.chargerConsultations();
  }

  private construireParamsRecherche(): any {
    const params: any = {
      page: this.pageActuelle,
      page_size: this.taillePage
    };

    if (this.filtrePatient) params.patient = this.filtrePatient;
    if (this.filtrePraticien) params.praticien = this.filtrePraticien;
    if (this.filtreDateDebut) params.date_debut = this.filtreDateDebut;
    if (this.filtreDateFin) params.date_fin = this.filtreDateFin;

    return params;
  }

  rechercherConsultations(terme: string): void {
    this.chargement = true;
    this.consultationsService.rechercherConsultations(terme).subscribe({
      next: (consultations) => {
        this.consultations = consultations;
        this.totalElements = consultations.length;
        this.chargement = false;
        this.animerEntreeCards();
      },
      error: (error) => {
        console.error('Erreur lors de la recherche:', error);
        this.chargement = false;
      }
    });
  }

  // Actions CRUD
  creerConsultation(): void {
    this.modeEdition = false;
    this.consultationSelectionnee = null;
    this.formulaireConsultation.reset();
    const maintenant = new Date();
    maintenant.setMinutes(maintenant.getMinutes() - maintenant.getTimezoneOffset());
    this.formulaireConsultation.patchValue({ date: maintenant.toISOString().slice(0, 16) });
    if (!this.patients.length) this.chargerPatients();
    if (!this.praticiens.length) this.chargerPraticiens();
    this.afficherFormulaire = true;
    this.animerEntreeModal();
  }

  modifierConsultation(consultation: Consultation): void {
    this.modeEdition = true;
    this.consultationSelectionnee = consultation;
    
    this.formulaireConsultation.patchValue({
      patient: consultation.patient,
      dossier: consultation.dossier,
      rendez_vous: consultation.rendez_vous,
      praticien: consultation.praticien,
      date: consultation.date,
      motif: consultation.motif,
      observations: consultation.observations,
      diagnostic: consultation.diagnostic,
      notes: consultation.notes
    });
    
    this.afficherFormulaire = true;
    this.animerEntreeModal();
  }

  enregistrerConsultation(): void {
    if (this.formulaireConsultation.invalid) {
      this.marquerFormulairesCommeInvalides();
      return;
    }

    const raw = this.formulaireConsultation.getRawValue();
    let dateIso = raw.date;
    if (dateIso && !String(dateIso).includes('Z') && !String(dateIso).includes('+')) {
      dateIso = new Date(dateIso).toISOString();
    }
    const patientId = raw.patient ? Number(raw.patient) : null;
    const patient = this.patients.find((p) => p.id === patientId);
    
    // Construire l'objet de données en filtrant les valeurs null/undefined
    const donnees: any = {
      patient: patientId,
      date: dateIso,
      motif: raw.motif,
      diagnostic: raw.diagnostic,
      observations: raw.observations || '',
      notes: raw.notes || ''
    };

    // Dossier : utiliser celui du formulaire, sinon celui du patient (UUID ou number)
    const dossierVal = raw.dossier || patient?.dossier_id;
    if (dossierVal) {
      donnees.dossier = dossierVal;
    }
    // Si dossier absent, le backend le déduit du patient via perform_create

    // Champs optionnels : n'inclure que si présents
    if (raw.praticien) {
      donnees.praticien = Number(raw.praticien);
    }
    if (raw.rendez_vous) {
      donnees.rendez_vous = Number(raw.rendez_vous);
    }

    console.log('DEBUG: Données envoyées pour consultation:', JSON.stringify(donnees, null, 2));

    const operation = this.modeEdition
      ? this.consultationsService.updateConsultation(this.consultationSelectionnee!.id, donnees)
      : this.consultationsService.createConsultation(donnees);

    operation.subscribe({
      next: (consultation) => {
        const message = this.modeEdition ? 'Consultation modifiée avec succès' : 'Consultation créée avec succès';
        this.afficherNotificationSucces(message);
        this.fermerFormulaire();
        this.chargerConsultations();
      },
      error: (error) => {
        console.error('Erreur lors de l\'enregistrement:', error);
        console.error('Détail erreur:', JSON.stringify(error?.error, null, 2));
        console.error('Status:', error?.status);
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: `Impossible d'enregistrer la consultation. ${error?.error?.detail || JSON.stringify(error?.error) || 'Veuillez vérifier les données.'}`
        });
      }
    });
  }

  confirmerSuppressionConsultation(consultation: Consultation): void {
    this.suppressionEnCours = true;
    
    this.dialogueService.confirmer({
      titre: 'Confirmation de suppression',
      message: `Êtes-vous sûr de vouloir supprimer la consultation du ${new Date(consultation.date).toLocaleDateString('fr-FR')} pour ${consultation.patient_prenom} ${consultation.patient_nom} ?`,
      boutonOk: 'Supprimer',
      boutonAnnuler: 'Annuler'
    }).subscribe(confirme => {
      if (confirme) {
        this.supprimerConsultation(consultation);
      } else {
        this.suppressionEnCours = false;
      }
    });
  }

  supprimerConsultation(consultation: Consultation): void {
    this.consultationsService.deleteConsultation(consultation.id).subscribe({
      next: () => {
        this.afficherNotificationSucces('Consultation supprimée avec succès');
        this.suppressionEnCours = false;
        this.chargerConsultations();
      },
      error: (error) => {
        console.error('Erreur lors de la suppression:', error);
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: 'Impossible de supprimer la consultation.'
        });
        this.suppressionEnCours = false;
      }
    });
  }

  voirDetailsConsultation(consultation: Consultation): void {
    this.consultationSelectionnee = consultation;
    this.afficherDetails = true;
    
    // Charger les données complémentaires
    this.chargerDonneesConsultation(consultation.id);
    this.animerEntreeModal();
  }

  private chargerDonneesConsultation(consultationId: number): void {
    // Charger les actes
    this.consultationsService.getActesConsultation(consultationId).subscribe({
      next: (actes) => {
        this.actesConsultation = actes;
      },
      error: (error) => {
        console.error('Erreur lors du chargement des actes:', error);
        this.actesConsultation = [];
      }
    });

    // Charger les photos
    this.consultationsService.getPhotosConsultation(consultationId).subscribe({
      next: (photos) => {
        this.photosConsultation = photos;
      },
      error: (error) => {
        console.error('Erreur lors du chargement des photos:', error);
        this.photosConsultation = [];
      }
    });
  }

  // Gestion des actes
  ajouterActe(): void {
    if (this.formulaireActe.invalid) {
      this.formulaireActe.markAllAsTouched();
      return;
    }

    const acte = {
      ...this.formulaireActe.value,
      consultation: this.consultationSelectionnee!.id
    };

    this.consultationsService.createActe(acte).subscribe({
      next: (nouvelActe) => {
        this.actesConsultation.push(nouvelActe);
        this.formulaireActe.reset();
        this.afficherNotificationSucces('Acte ajouté avec succès');
      },
      error: (error) => {
        console.error('Erreur lors de l\'ajout de l\'acte:', error);
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: 'Impossible d\'ajouter l\'acte.'
        });
      }
    });
  }

  supprimerActe(acte: ActeRealise): void {
    this.consultationsService.deleteActe(acte.id).subscribe({
      next: () => {
        this.actesConsultation = this.actesConsultation.filter(a => a.id !== acte.id);
        this.afficherNotificationSucces('Acte supprimé avec succès');
      },
      error: (error) => {
        console.error('Erreur lors de la suppression de l\'acte:', error);
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: 'Impossible de supprimer l\'acte.'
        });
      }
    });
  }

  exporterConsultations(format: 'csv' | 'excel' | 'pdf'): void {
    const filters = this.construireParamsRecherche();

    if (format === 'csv') {
      this.consultationsService.exporterCsv(filters).subscribe({
        next: (blob) => this.telechargerBlob(blob, 'consultations.csv'),
        error: () => this.exporterConsultationsLocalement('csv'),
      });
      return;
    }

    this.exporterConsultationsLocalement(format === 'excel' ? 'csv' : 'csv');
    this.afficherNotificationSucces(
      `Export ${format.toUpperCase()} : fichier CSV généré (ouvrez-le dans Excel si besoin).`
    );
  }

  private exporterConsultationsLocalement(ext: string): void {
    if (!this.consultations.length) {
      this.dialogueService.erreur({
        titre: 'Export',
        message: 'Aucune consultation à exporter. Chargez ou créez des consultations d\'abord.',
      });
      return;
    }
    const entetes = ['ID', 'Patient', 'Date', 'Motif', 'Diagnostic', 'Observations'];
    const lignes = this.consultations.map((c) =>
      [
        c.id,
        `${c.patient_prenom} ${c.patient_nom}`,
        c.date,
        c.motif,
        c.diagnostic,
        (c.observations || '').replace(/"/g, '""'),
      ]
        .map((v) => `"${v}"`)
        .join(';')
    );
    const csv = [entetes.join(';'), ...lignes].join('\n');
    const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8' });
    this.telechargerBlob(blob, `consultations.${ext}`);
    this.afficherNotificationSucces('Export téléchargé');
  }

  private telechargerBlob(blob: Blob, filename: string): void {
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    window.URL.revokeObjectURL(url);
    this.afficherNotificationSucces(`Fichier ${filename} téléchargé`);
  }

  rafraichirTout(): void {
    this.chargerPatients();
    this.chargerPraticiens();
    this.chargerRendezVous();
    this.chargerConsultations();
  }

  // Navigation UI
  fermerFormulaire(): void {
    this.afficherFormulaire = false;
    this.modeEdition = false;
    this.consultationSelectionnee = null;
    this.formulaireConsultation.reset();
    this.animerSortieModal();
  }

  fermerDetails(): void {
    this.afficherDetails = false;
    this.consultationSelectionnee = null;
    this.actesConsultation = [];
    this.photosConsultation = [];
    this.animerSortieModal();
  }

  changerPage(page: number): void {
    this.pageActuelle = page;
    this.chargerConsultations();
  }

  // Animations
  private animerEntreeCards(): void {
    if (this.cardContainer) {
      const cards = this.cardContainer.nativeElement.querySelectorAll('.consultation-card');
      cards.forEach((card: Element, index: number) => {
        setTimeout(() => {
          card.classList.add('animate-in');
        }, index * 100);
      });
    }
  }

  private animerEntreeModal(): void {
    if (this.modalContent) {
      setTimeout(() => {
        this.modalContent.nativeElement.classList.add('modal-animate-in');
      }, 50);
    }
  }

  private animerSortieModal(): void {
    if (this.modalContent) {
      this.modalContent.nativeElement.classList.remove('modal-animate-in');
      this.modalContent.nativeElement.classList.add('modal-animate-out');
    }
  }

  // Utilitaires
  private marquerFormulairesCommeInvalides(): void {
    Object.keys(this.formulaireConsultation.controls).forEach(key => {
      const control = this.formulaireConsultation.get(key);
      if (control?.invalid) {
        control.markAsTouched();
      }
    });
  }

  private afficherNotificationSucces(message: string): void {
    this.dialogueService.succes({
      titre: 'Succès',
      message: message
    });
  }

  formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  // Getters pour les templates
  get f() { return this.formulaireConsultation.controls; }
  get fActe() { return this.formulaireActe.controls; }
}
