import { CommonModule } from '@angular/common';
import { Component, OnInit, ViewChild, inject } from '@angular/core';
import { FormArray, FormBuilder, FormGroup, FormsModule, ReactiveFormsModule, Validators } from '@angular/forms';
import { Subject, debounceTime, distinctUntilChanged } from 'rxjs';

import { SignatureCanvas } from '../../noyau/composants/signature-canvas/signature-canvas';
import { DialogueService } from '../../noyau/services/dialogue.service';
import { Patient, Patients } from '../../noyau/services/patients';
import { Personnel, PersonnelService } from '../../noyau/services/personnel.service';
import {
  Prescription,
  PrescriptionPayload,
  PrescriptionsService,
  StatutPrescription,
} from '../../noyau/services/prescriptions.service';

@Component({
  selector: 'app-prescriptions',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule, SignatureCanvas],
  templateUrl: './prescriptions.component.html',
  styleUrl: './prescriptions.component.scss',
})
export class PrescriptionsComponent implements OnInit {
  private readonly prescriptionsService = inject(PrescriptionsService);
  private readonly patientsService = inject(Patients);
  private readonly personnelService = inject(PersonnelService);
  private readonly dialogueService = inject(DialogueService);
  private readonly fb = inject(FormBuilder);

  @ViewChild('canvasSignature') canvasSignature?: SignatureCanvas;

  prescriptions: Prescription[] = [];
  patients: Patient[] = [];
  praticiens: Personnel[] = [];

  chargement = false;
  afficherFormulaire = false;
  vueModal: 'formulaire' | 'apercu' = 'formulaire';
  modeEdition = false;
  enregistrementEnCours = false;
  prescriptionEnEdition: Prescription | null = null;
  prescriptionEnTelechargement: number | null = null;

  // Signature
  prescriptionASign: Prescription | null = null;
  signaturePresente = false;
  signatureEnCours = false;

  alerteAllergie: { etape: 1 | 2; medicaments: string[]; allergiesPatient: string } | null = null;
  readonly today = new Date();

  termeRecherche = '';
  filtreStatut: StatutPrescription | '' = '';
  private readonly termeRecherche$ = new Subject<string>();

  formulaire!: FormGroup;

  readonly statuts: { valeur: StatutPrescription; libelle: string }[] = [
    { valeur: 'active', libelle: 'Active' },
    { valeur: 'terminee', libelle: 'Terminée' },
    { valeur: 'annulee', libelle: 'Annulée' },
  ];

  ngOnInit(): void {
    this.initialiserFormulaire();
    this.configurerRecherche();
    this.chargerPatients();
    this.chargerPraticiens();
    this.chargerPrescriptions();
  }

  private initialiserFormulaire(): void {
    this.formulaire = this.fb.group({
      patient: [null, Validators.required],
      dossier: [null, Validators.required],
      praticien: [null],
      titre: ['', Validators.required],
      statut: ['active' as StatutPrescription, Validators.required],
      note_praticien: [''],
      conseils: [''],
      recommandations: [''],
      lignes: this.fb.array([this.creerLigne()]),
    });
  }

  private creerLigne(): FormGroup {
    return this.fb.group({
      medicament: ['', Validators.required],
      posologie: [''],
      duree: [''],
      remarques: [''],
    });
  }

  get lignes(): FormArray {
    return this.formulaire.get('lignes') as FormArray;
  }

  ajouterLigne(): void {
    this.lignes.push(this.creerLigne());
  }

  retirerLigne(index: number): void {
    if (this.lignes.length > 1) {
      this.lignes.removeAt(index);
    }
  }

  onPatientChange(patientId: number | string | null): void {
    const id = Number(patientId) || null;
    if (!id) return;
    const patient = this.patients.find((p) => p.id === id);
    // dossier_id est un UUID (pas un entier) : ne jamais le passer dans
    // Number(), qui le transformerait silencieusement en NaN et ferait
    // échouer la création côté backend avec un 400.
    if (patient?.dossier_id) {
      this.formulaire.patchValue({ dossier: patient.dossier_id });
    }
  }

  private configurerRecherche(): void {
    this.termeRecherche$.pipe(debounceTime(300), distinctUntilChanged()).subscribe(() => this.chargerPrescriptions());
  }

  surRecherche(valeur: string): void {
    this.termeRecherche = valeur;
    this.termeRecherche$.next(valeur);
  }

  filtrerParStatut(statut: StatutPrescription | ''): void {
    this.filtreStatut = statut;
    this.chargerPrescriptions();
  }

  private chargerPatients(): void {
    this.patientsService.lister().subscribe({ next: (patients) => (this.patients = patients) });
  }

  private chargerPraticiens(): void {
    // Seuls les chirurgiens-dentistes actifs peuvent être sélectionnés comme
    // praticien prescripteur (pas les patients, ni le personnel inactif).
    this.personnelService
      .getPersonnel({ role: 'chirurgien_dentiste', statut: 'actif' })
      .subscribe({ next: (praticiens) => (this.praticiens = praticiens) });
  }

  chargerPrescriptions(): void {
    this.chargement = true;
    this.prescriptionsService
      .lister({
        statut: this.filtreStatut || undefined,
        search: this.termeRecherche || undefined,
      })
      .subscribe({
        next: (prescriptions) => {
          this.prescriptions = prescriptions;
          this.chargement = false;
        },
        error: () => (this.chargement = false),
      });
  }

  ouvrirCreation(): void {
    this.modeEdition = false;
    this.vueModal = 'formulaire';
    this.alerteAllergie = null;
    this.prescriptionEnEdition = null;
    this.formulaire.reset({ statut: 'active' });
    this.lignes.clear();
    this.lignes.push(this.creerLigne());
    this.afficherFormulaire = true;
  }

  ouvrirEdition(prescription: Prescription): void {
    this.modeEdition = true;
    this.vueModal = 'formulaire';
    this.alerteAllergie = null;
    this.prescriptionEnEdition = prescription;
    this.lignes.clear();
    if (prescription.lignes.length === 0) {
      this.lignes.push(this.creerLigne());
    } else {
      prescription.lignes.forEach((ligne) => {
        this.lignes.push(
          this.fb.group({
            medicament: [ligne.medicament, Validators.required],
            posologie: [ligne.posologie],
            duree: [ligne.duree],
            remarques: [ligne.remarques],
          })
        );
      });
    }
    this.formulaire.patchValue({
      patient: prescription.patient,
      dossier: prescription.dossier,
      praticien: prescription.praticien ?? null,
      titre: prescription.titre,
      statut: prescription.statut,
      note_praticien: prescription.note_praticien,
      conseils: prescription.conseils,
      recommandations: prescription.recommandations,
    });
    this.afficherFormulaire = true;
  }

  fermerFormulaire(): void {
    this.afficherFormulaire = false;
    this.vueModal = 'formulaire';
    this.alerteAllergie = null;
    this.prescriptionEnEdition = null;
  }

  get patientSelectionne(): Patient | null {
    const id = Number(this.formulaire?.get('patient')?.value);
    return this.patients.find((p) => p.id === id) ?? null;
  }

  get praticienSelectionne(): Personnel | null {
    const id = Number(this.formulaire?.get('praticien')?.value);
    return this.praticiens.find((p) => p.id === id) ?? null;
  }

  /** Ouvre l'aperçu stylisé de l'ordonnance avant son enregistrement définitif. */
  ouvrirApercu(): void {
    if (this.formulaire.invalid) {
      this.formulaire.markAllAsTouched();
      return;
    }
    this.vueModal = 'apercu';
  }

  revenirAuFormulaire(): void {
    this.vueModal = 'formulaire';
    this.alerteAllergie = null;
  }

  /** Normalise un texte pour comparaison : minuscules + accents retirés (ex: "Paracétamol" ≈ "paracetamol"). */
  private normaliser(texte: string): string {
    const debutPlageCombinants = String.fromCharCode(768); // U+0300
    const finPlageCombinants = String.fromCharCode(879); // U+036F
    const sansAccents = new RegExp('[' + debutPlageCombinants + '-' + finPlageCombinants + ']', 'g');
    return texte.normalize('NFD').replace(sansAccents, '').toLowerCase().trim();
  }

  /**
   * Compare chaque médicament de l'ordonnance au texte libre des allergies
   * du patient (simple correspondance de sous-chaîne, insensible à la
   * casse et aux accents) : suffisant tant qu'il n'existe pas de
   * référentiel médicament/allergène structuré côté backend.
   */
  private detecterConflitsAllergies(): string[] {
    const allergiesPatientBrut = this.patientSelectionne?.allergies ?? '';
    if (!allergiesPatientBrut.trim()) return [];

    const tokensAllergies = allergiesPatientBrut
      .split(/[,;/]| et /i)
      .map((t) => this.normaliser(t))
      .filter((t) => t.length > 1);

    const medicaments: string[] = this.lignes.controls
      .map((c) => (c.get('medicament')?.value ?? '').toString().trim())
      .filter((m: string) => m.length > 0);

    const conflits = new Set<string>();
    for (const medicament of medicaments) {
      const medicamentNorm = this.normaliser(medicament);
      if (!medicamentNorm) continue;
      for (const allergie of tokensAllergies) {
        if (medicamentNorm.includes(allergie) || allergie.includes(medicamentNorm)) {
          conflits.add(medicament);
        }
      }
    }
    return Array.from(conflits);
  }

  /** Étape finale déclenchée depuis l'aperçu : vérifie les allergies avant d'enregistrer. */
  validerDepuisApercu(): void {
    const conflits = this.detecterConflitsAllergies();
    if (conflits.length > 0) {
      this.alerteAllergie = {
        etape: 1,
        medicaments: conflits,
        allergiesPatient: this.patientSelectionne?.allergies ?? '',
      };
      return;
    }
    this.enregistrer();
  }

  passerAlerteEtapeDeux(): void {
    if (this.alerteAllergie) this.alerteAllergie = { ...this.alerteAllergie, etape: 2 };
  }

  annulerAlerteAllergie(): void {
    this.alerteAllergie = null;
  }

  confirmerPrescriptionMalgreAllergie(): void {
    this.alerteAllergie = null;
    this.enregistrer();
  }

  private enregistrer(): void {
    const valeurs = this.formulaire.getRawValue();
    const payload: PrescriptionPayload = {
      patient: Number(valeurs.patient),
      dossier: valeurs.dossier || null,
      praticien: valeurs.praticien ? Number(valeurs.praticien) : null,
      titre: valeurs.titre,
      statut: valeurs.statut,
      note_praticien: valeurs.note_praticien || '',
      conseils: valeurs.conseils || '',
      recommandations: valeurs.recommandations || '',
      lignes: valeurs.lignes,
    };

    this.enregistrementEnCours = true;
    const requete = this.modeEdition && this.prescriptionEnEdition
      ? this.prescriptionsService.modifier(this.prescriptionEnEdition.id, payload)
      : this.prescriptionsService.creer(payload);

    requete.subscribe({
      next: () => {
        this.enregistrementEnCours = false;
        this.fermerFormulaire();
        this.chargerPrescriptions();
        this.dialogueService.succes({
          titre: this.modeEdition ? 'Prescription modifiée' : 'Prescription créée',
          message: this.modeEdition
            ? "L'ordonnance a été mise à jour avec succès."
            : "La nouvelle ordonnance a été enregistrée avec succès.",
        }).subscribe();
      },
      error: (erreur) => {
        this.enregistrementEnCours = false;
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: erreur?.error?.detail || "Impossible d'enregistrer la prescription. Vérifiez les champs obligatoires.",
        }).subscribe();
      },
    });
  }

  confirmerSuppression(prescription: Prescription): void {
    this.dialogueService
      .confirmer({
        titre: 'Supprimer la prescription',
        message: `Supprimer définitivement l'ordonnance "${prescription.titre || 'sans titre'}" de ${prescription.patient_prenom} ${prescription.patient_nom} ?`,
        boutonOk: 'Supprimer',
        boutonAnnuler: 'Annuler',
      })
      .subscribe((confirme) => {
        if (confirme) this.supprimer(prescription);
      });
  }

  private supprimer(prescription: Prescription): void {
    this.prescriptionsService.supprimer(prescription.id).subscribe({
      next: () => this.chargerPrescriptions(),
      error: () =>
        this.dialogueService.erreur({ titre: 'Erreur', message: 'Impossible de supprimer cette prescription.' }).subscribe(),
    });
  }

  ouvrirPdf(prescription: Prescription): void {
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

  libelleStatut(statut: StatutPrescription): string {
    return this.statuts.find((s) => s.valeur === statut)?.libelle ?? statut;
  }

  ouvrirSignature(prescription: Prescription): void {
    this.prescriptionASign = prescription;
    this.signaturePresente = false;
    this.signatureEnCours = false;
  }

  fermerSignature(): void {
    this.prescriptionASign = null;
    this.signaturePresente = false;
    this.signatureEnCours = false;
    this.canvasSignature?.effacer();
  }

  signerEtImprimer(): void {
    if (!this.prescriptionASign || !this.canvasSignature) return;
    const b64 = this.canvasSignature.exporter();
    if (!b64) return;

    this.signatureEnCours = true;
    this.prescriptionsService.signerPdf(this.prescriptionASign.id, b64).subscribe({
      next: (blob) => {
        this.signatureEnCours = false;
        this.fermerSignature();
        const url = URL.createObjectURL(blob);
        const w = window.open(url, '_blank');
        if (w) {
          w.addEventListener('load', () => {
            try { w.print(); } catch { /* le viewer PDF propose l'impression */ }
          });
        }
      },
      error: () => {
        this.signatureEnCours = false;
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: 'Impossible de générer le PDF signé.',
        }).subscribe();
      },
    });
  }
}

// #EbaJioloLewis
