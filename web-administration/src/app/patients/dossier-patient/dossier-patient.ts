import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import QRCode from 'qrcode';

import { Patients, Patient } from '../../noyau/services/patients';
import { DossierService, Dossier } from '../../noyau/services/dossier.service';
import { ConsultationsService, Consultation } from '../../noyau/services/consultations.service';
import { DialogueService } from '../../noyau/services/dialogue.service';
import { Prescription, PrescriptionsService } from '../../noyau/services/prescriptions.service';

type CleDePage = 'identite' | 'medical' | 'carte' | 'historique' | 'prescriptions';

@Component({
  selector: 'app-dossier-patient',
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './dossier-patient.html',
  styleUrl: './dossier-patient.scss',
})
export class DossierPatient implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly fb = inject(FormBuilder);
  private readonly patientsService = inject(Patients);
  private readonly dossierService = inject(DossierService);
  private readonly consultationsService = inject(ConsultationsService);
  private readonly prescriptionsService = inject(PrescriptionsService);
  private readonly dialogueService = inject(DialogueService);

  readonly pages: { cle: CleDePage; label: string; icone: string }[] = [
    { cle: 'identite', label: 'Identité', icone: 'bi-person-vcard' },
    { cle: 'medical', label: 'Médical', icone: 'bi-heart-pulse' },
    { cle: 'carte', label: 'Carte & QR', icone: 'bi-qr-code' },
    { cle: 'historique', label: 'Historique', icone: 'bi-clock-history' },
    { cle: 'prescriptions', label: 'Prescriptions', icone: 'bi-capsule-pill' },
  ];

  patientId = 0;
  patient: Patient | null = null;
  dossier: Dossier | null = null;
  consultations: Consultation[] = [];
  prescriptions: Prescription[] = [];
  qrDataUrl = '';

  loading = true;
  chargementConsultations = false;
  chargementPrescriptions = false;
  prescriptionEnTelechargement: number | null = null;
  erreur = '';

  ouvert = false;
  pageActive: CleDePage = 'identite';

  editIdentite = false;
  editMedical = false;
  enregistrementEnCours = false;

  formIdentite = this.fb.group({
    prenom: ['', Validators.required],
    nom: ['', Validators.required],
    date_naissance: [''],
    sexe: ['M'],
    telephone: [''],
    email: [''],
    adresse: [''],
  });

  formMedical = this.fb.group({
    groupe_sanguin: ['inconnu'],
    taille_cm: [null as number | null],
    poids_kg: [null as number | null],
    symptomes: [''],
    allergies: [''],
    antecedents: [''],
    notes_medicales: [''],
  });

  ngOnInit(): void {
    this.patientId = Number(this.route.snapshot.paramMap.get('id'));
    if (this.patientId) {
      this.chargerTout();
    } else {
      this.erreur = 'Aucun identifiant de patient spécifié';
      this.loading = false;
    }
  }

  retryChargement(): void {
    this.erreur = '';
    this.chargerTout();
  }

  private chargerTout(): void {
    this.loading = true;
    this.patientsService.detail(this.patientId).subscribe({
      next: (patient) => {
        this.patient = patient;
        this.remplirFormulaires(patient, null);
        this.genererQr(patient);
        this.loading = false;
        if (patient.dossier_id) {
          this.chargerDossier(patient.dossier_id);
        }
        this.chargerHistorique();
        this.chargerPrescriptions();
      },
      error: () => {
        this.erreur = 'Impossible de charger les informations du patient';
        this.loading = false;
      },
    });
  }

  private chargerDossier(dossierId: string): void {
    this.dossierService.detail(dossierId).subscribe({
      next: (dossier) => {
        this.dossier = dossier;
        this.formMedical.patchValue({
          allergies: dossier.allergies || '',
          antecedents: dossier.antecedents || '',
          notes_medicales: dossier.notes_medicales || '',
        });
      },
      error: () => undefined,
    });
  }

  private chargerHistorique(): void {
    this.chargementConsultations = true;
    this.consultationsService.getConsultations({ patient: this.patientId }).subscribe({
      next: (consultations) => {
        this.consultations = [...consultations].sort(
          (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
        );
        this.chargementConsultations = false;
      },
      error: () => {
        this.chargementConsultations = false;
      },
    });
  }

  private chargerPrescriptions(): void {
    this.chargementPrescriptions = true;
    this.prescriptionsService.historiquePatient(this.patientId).subscribe({
      next: (prescriptions) => {
        this.prescriptions = [...prescriptions].sort(
          (a, b) => new Date(b.cree_le).getTime() - new Date(a.cree_le).getTime()
        );
        this.chargementPrescriptions = false;
      },
      error: () => {
        this.chargementPrescriptions = false;
      },
    });
  }

  telechargerPrescriptionPdf(prescription: Prescription): void {
    this.prescriptionEnTelechargement = prescription.id;
    this.prescriptionsService.telechargerPdf(prescription.id).subscribe({
      next: (blob) => {
        this.prescriptionEnTelechargement = null;
        window.open(URL.createObjectURL(blob), '_blank');
      },
      error: () => {
        this.prescriptionEnTelechargement = null;
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: "Impossible de récupérer le PDF de cette ordonnance.",
        }).subscribe();
      },
    });
  }

  private genererQr(patient: Patient): void {
    if (!patient.qr_token) return;
    QRCode.toDataURL(patient.qr_token, { width: 280, margin: 1 })
      .then((dataUrl) => (this.qrDataUrl = dataUrl))
      .catch(() => undefined);
  }

  private remplirFormulaires(patient: Patient, dossier: Dossier | null): void {
    this.formIdentite.patchValue({
      prenom: patient.prenom,
      nom: patient.nom,
      date_naissance: patient.date_naissance || '',
      sexe: patient.sexe || 'M',
      telephone: patient.telephone || '',
      email: patient.email || '',
      adresse: patient.adresse || '',
    });
    this.formMedical.patchValue({
      groupe_sanguin: patient.groupe_sanguin || 'inconnu',
      taille_cm: patient.taille_cm ? Number(patient.taille_cm) : null,
      poids_kg: patient.poids_kg ? Number(patient.poids_kg) : null,
      symptomes: patient.symptomes || '',
      allergies: dossier?.allergies || '',
      antecedents: dossier?.antecedents || '',
      notes_medicales: dossier?.notes_medicales || '',
    });
  }

  // ----------------------------------------
  // NAVIGATION DU CARNET
  // ----------------------------------------

  ouvrirCarnet(): void {
    this.ouvert = true;
  }

  fermerCarnet(): void {
    this.ouvert = false;
    this.editIdentite = false;
    this.editMedical = false;
  }

  allerPage(cle: CleDePage): void {
    this.pageActive = cle;
  }

  pageSuivante(): void {
    const index = this.pages.findIndex((p) => p.cle === this.pageActive);
    if (index < this.pages.length - 1) {
      this.pageActive = this.pages[index + 1].cle;
    }
  }

  pagePrecedente(): void {
    const index = this.pages.findIndex((p) => p.cle === this.pageActive);
    if (index > 0) {
      this.pageActive = this.pages[index - 1].cle;
    }
  }

  get estPremierePage(): boolean {
    return this.pageActive === this.pages[0].cle;
  }

  get estDernierePage(): boolean {
    return this.pageActive === this.pages[this.pages.length - 1].cle;
  }

  // ----------------------------------------
  // CRUD — IDENTITÉ
  // ----------------------------------------

  activerEditionIdentite(): void {
    if (this.patient) {
      this.remplirFormulaires(this.patient, this.dossier);
    }
    this.editIdentite = true;
  }

  annulerEditionIdentite(): void {
    this.editIdentite = false;
    if (this.patient) {
      this.remplirFormulaires(this.patient, this.dossier);
    }
  }

  enregistrerIdentite(): void {
    if (this.formIdentite.invalid || !this.patient) {
      this.formIdentite.markAllAsTouched();
      return;
    }
    this.enregistrementEnCours = true;
    const payload: Record<string, unknown> = { ...this.formIdentite.getRawValue() };
    const ageCalc = this.calculerAge(payload['date_naissance'] as string | undefined);
    if (ageCalc !== null) payload['age'] = ageCalc;
    this.patientsService.modifier(this.patientId, payload as any).subscribe({
      next: (patient) => {
        this.patient = patient;
        this.editIdentite = false;
        this.enregistrementEnCours = false;
        this.dialogueService
          .succes({ titre: 'Carnet mis à jour', message: 'Les informations personnelles ont été enregistrées.' })
          .subscribe();
      },
      error: () => {
        this.enregistrementEnCours = false;
        this.dialogueService
          .erreur({ titre: 'Erreur', message: "Impossible d'enregistrer les informations personnelles." })
          .subscribe();
      },
    });
  }

  // ----------------------------------------
  // CRUD — MÉDICAL (Patient + Dossier)
  // ----------------------------------------

  activerEditionMedical(): void {
    if (this.patient) {
      this.remplirFormulaires(this.patient, this.dossier);
    }
    this.editMedical = true;
  }

  annulerEditionMedical(): void {
    this.editMedical = false;
    if (this.patient) {
      this.remplirFormulaires(this.patient, this.dossier);
    }
  }

  enregistrerMedical(): void {
    if (!this.patient) return;
    this.enregistrementEnCours = true;
    const valeurs = this.formMedical.getRawValue();

    const payloadPatient = {
      groupe_sanguin: valeurs.groupe_sanguin,
      taille_cm: valeurs.taille_cm,
      poids_kg: valeurs.poids_kg,
      symptomes: valeurs.symptomes,
    };

    this.patientsService.modifier(this.patientId, payloadPatient as any).subscribe({
      next: (patient) => {
        this.patient = patient;
        this.enregistrerDossierMedical(valeurs);
      },
      error: () => {
        this.enregistrementEnCours = false;
        this.dialogueService
          .erreur({ titre: 'Erreur', message: "Impossible d'enregistrer les informations médicales." })
          .subscribe();
      },
    });
  }

  private enregistrerDossierMedical(valeurs: {
    allergies: string | null;
    antecedents: string | null;
    notes_medicales: string | null;
  }): void {
    const dossierId = this.patient?.dossier_id;
    const payloadDossier = {
      allergies: valeurs.allergies || '',
      antecedents: valeurs.antecedents || '',
      notes_medicales: valeurs.notes_medicales || '',
    };

    if (!dossierId) {
      this.enregistrementEnCours = false;
      this.editMedical = false;
      this.dialogueService
        .succes({ titre: 'Carnet mis à jour', message: 'Les informations médicales ont été enregistrées.' })
        .subscribe();
      return;
    }

    this.dossierService.modifier(dossierId, payloadDossier).subscribe({
      next: (dossier) => {
        this.dossier = dossier;
        this.enregistrementEnCours = false;
        this.editMedical = false;
        this.dialogueService
          .succes({ titre: 'Carnet mis à jour', message: 'Les informations médicales ont été enregistrées.' })
          .subscribe();
      },
      error: () => {
        this.enregistrementEnCours = false;
        this.dialogueService
          .erreur({
            titre: 'Erreur partielle',
            message: 'Les données patient ont été enregistrées, mais les allergies/antécédents du dossier non.',
          })
          .subscribe();
      },
    });
  }

  // ----------------------------------------
  // HISTORIQUE DES CONSULTATIONS
  // ----------------------------------------

  nouvelleConsultation(): void {
    this.router.navigate(['/consultations']);
  }

  supprimerConsultation(consultation: Consultation): void {
    this.dialogueService
      .confirmer({
        titre: 'Supprimer la consultation',
        message: `Supprimer la consultation du ${this.formatDate(consultation.date)} ? Cette action est irréversible.`,
        boutonOk: 'Supprimer',
        boutonAnnuler: 'Annuler',
      })
      .subscribe((confirme) => {
        if (!confirme) return;
        this.consultationsService.deleteConsultation(consultation.id).subscribe({
          next: () => {
            this.consultations = this.consultations.filter((c) => c.id !== consultation.id);
            this.dialogueService
              .succes({ titre: 'Consultation supprimée', message: 'La consultation a été retirée de l\'historique.' })
              .subscribe();
          },
          error: () => {
            this.dialogueService
              .erreur({ titre: 'Erreur', message: 'Impossible de supprimer cette consultation.' })
              .subscribe();
          },
        });
      });
  }

  // ----------------------------------------
  // UTILITAIRES D'AFFICHAGE
  // ----------------------------------------

  calculerAge(dateNaissance?: string): number | null {
    if (!dateNaissance) return null;
    const naissance = new Date(dateNaissance);
    const aujourdHui = new Date();
    let age = aujourdHui.getFullYear() - naissance.getFullYear();
    const moisDiff = aujourdHui.getMonth() - naissance.getMonth();
    if (moisDiff < 0 || (moisDiff === 0 && aujourdHui.getDate() < naissance.getDate())) {
      age--;
    }
    return age;
  }

  formatDate(date?: string): string {
    if (!date) return 'Non renseignée';
    return new Date(date).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' });
  }

  obtenirInitiale(): string {
    if (!this.patient) return '?';
    return (this.patient.nom?.[0] || this.patient.prenom?.[0] || '?').toUpperCase();
  }

  obtenirLabelStatut(statut?: string): string {
    const libelles: Record<string, string> = {
      nouveau: 'Nouveau patient',
      en_cours: 'Suivi en cours',
      opere: 'Traité',
      termine: 'Parcours terminé',
    };
    return libelles[statut || ''] || 'Nouveau patient';
  }

  obtenirCouleurStatut(statut?: string): string {
    const couleurs: Record<string, string> = {
      nouveau: '#3b82f6',
      en_cours: '#f59e0b',
      opere: '#10b981',
      termine: '#6b7280',
    };
    return couleurs[statut || ''] || '#3b82f6';
  }

  telechargerQr(): void {
    if (!this.qrDataUrl || !this.patient) return;
    const lien = document.createElement('a');
    lien.href = this.qrDataUrl;
    lien.download = `qr-${this.patient.numero_dossier || this.patient.id}.png`;
    document.body.appendChild(lien);
    lien.click();
    document.body.removeChild(lien);
  }
}

// #EbaJioloLewis
