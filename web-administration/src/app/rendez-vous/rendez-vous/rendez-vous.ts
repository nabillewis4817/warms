import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';

import { RendezVousService, RendezVous } from '../../noyau/services/rendez-vous';
import { CompteRenduAssistantService } from '../../noyau/services/compte-rendu-assistant.service';
import { Patients } from '../../noyau/services/patients';
import { DialogueService } from '../../noyau/services/dialogue.service';

@Component({
  selector: 'app-rendez-vous',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './rendez-vous.html',
  styleUrl: './rendez-vous.scss',
})
export class RendezVousComponent implements OnInit {
  private readonly rendezVousService = inject(RendezVousService);
  private readonly compteRenduSvc = inject(CompteRenduAssistantService);
  private readonly patientsService = inject(Patients);
  private readonly fb = inject(FormBuilder);
  private readonly dialogueService = inject(DialogueService);

  rendezVousList: RendezVous[] = [];
  patientsList: any[] = [];
  loading = false;
  showModal = false;
  editingItem: RendezVous | null = null;
  message = '';

  form = this.fb.group({
    patient: [null as number | null, Validators.required],
    date_heure: ['', Validators.required],
    duree: [30, [Validators.required, Validators.min(15), Validators.max(180)]],
    motif: [''],
    statut: ['programme', Validators.required],
    notes: ['']
  });

  ngOnInit(): void {
    this.loadRendezVous();
    this.loadPatients();
  }

  loadRendezVous(): void {
    this.loading = true;
    this.rendezVousService.lister().subscribe({
      next: (data) => {
        this.rendezVousList = data;
        this.loading = false;
      },
      error: (err) => {
        console.error('Erreur lors du chargement des rendez-vous:', err);
        this.message = 'Impossible de charger les rendez-vous';
        this.loading = false;
      }
    });
  }

  loadPatients(): void {
    this.patientsService.lister().subscribe({
      next: (data) => {
        this.patientsList = data;
      },
      error: (err) => {
        console.error('Erreur lors du chargement des patients:', err);
      }
    });
  }

  openModal(item?: RendezVous): void {
    this.editingItem = item || null;
    if (item) {
      this.form.patchValue({
        patient: item.patient,
        date_heure: item.date_heure,
        duree: item.duree,
        motif: item.motif,
        statut: item.statut,
        notes: item.notes
      });
    } else {
      this.form.reset({
        patient: null,
        date_heure: '',
        duree: 30,
        motif: '',
        statut: 'programme',
        notes: ''
      });
    }
    this.showModal = true;
  }

  closeModal(): void {
    this.showModal = false;
    this.editingItem = null;
    this.form.reset();
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const formData = this.form.value;
    // Filtrer les valeurs null pour éviter les erreurs de type
    const cleanData = Object.fromEntries(
      Object.entries(formData).filter(([_, value]) => value !== null && value !== '')
    );

    const request = this.editingItem
      ? this.rendezVousService.modifier(this.editingItem.id, cleanData)
      : this.rendezVousService.creer(cleanData);

    request.subscribe({
      next: (rdv: any) => {
        this.message = this.editingItem ? 'Rendez-vous modifié avec succès' : 'Rendez-vous créé avec succès';
        this.closeModal();
        this.loadRendezVous();
        // Déclencher l'assistant IA si le RDV est marqué effectué
        if (rdv && rdv.statut === 'effectue') {
          const patient = this.patientsList.find((p: any) => p.id === (rdv.patient ?? rdv.patient_id));
          this.compteRenduSvc.declencherGeneration({
            type_action:    'rendez_vous',
            reference_id:   rdv.id,
            patient_id:     rdv.patient ?? rdv.patient_id,
            patient_nom:    patient?.nom    ?? rdv.patient_nom    ?? '',
            patient_prenom: patient?.prenom ?? rdv.patient_prenom ?? '',
            date:           rdv.debut ?? rdv.date_heure ?? '',
            motif:          rdv.motif ?? '',
            notes:          rdv.notes ?? '',
          });
        }
      },
        error: (err: any) => {
        console.error('Erreur lors de la sauvegarde:', err);
        const detail = err?.error;
        this.message = typeof detail === 'object'
          ? Object.values(detail).flat().join(' ')
          : (detail || 'Erreur lors de la sauvegarde du rendez-vous');
      }
    });
  }

  delete(item: RendezVous): void {
    this.dialogueService.confirmer({
      titre: 'Confirmation de suppression',
      message: `Êtes-vous sûr de vouloir supprimer le rendez-vous du ${item.date_heure} ?`,
      boutonOk: 'Supprimer',
      boutonAnnuler: 'Annuler'
    }).subscribe(confirme => {
      if (!confirme) return;
      this.rendezVousService.supprimer(item.id).subscribe({
        next: () => {
          this.message = 'Rendez-vous supprimé avec succès';
          this.loadRendezVous();
        },
        error: (err) => {
          console.error('Erreur lors de la suppression:', err);
          this.dialogueService.erreur({
            titre: 'Erreur',
            message: 'Impossible de supprimer le rendez-vous.'
          });
        }
      });
    });
  }

  getStatutColor(statut: string): string {
    switch (statut) {
      case 'programme': return '#0d6efd';
      case 'confirme': return '#28a745';
      case 'reporte': return '#ffc107';
      case 'effectue': return '#6c757d';
      case 'absent': return '#fd7e14';
      case 'annule': return '#dc3545';
      default: return '#6c757d';
    }
  }

  getStatutLabel(statut: string): string {
    switch (statut) {
      case 'programme': return 'Programmé';
      case 'confirme': return 'Confirmé';
      case 'reporte': return 'Reporté';
      case 'effectue': return 'Effectué';
      case 'absent': return 'Absent';
      case 'annule': return 'Annulé';
      default: return statut;
    }
  }
}
