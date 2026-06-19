import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';

import { AppelsService } from '../../noyau/services/appels';
import { Appel } from '../../noyau/services/appels';
import { Patients } from '../../noyau/services/patients';
import { DialogueService } from '../../noyau/services/dialogue.service';

@Component({
  selector: 'app-appels',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './appels.html',
  styleUrl: './appels.scss',
})
export class AppelsComponent implements OnInit {
  private readonly appelsService = inject(AppelsService);
  private readonly patientsService = inject(Patients);
  private readonly fb = inject(FormBuilder);
  private readonly router = inject(Router);
  private readonly dialogueService = inject(DialogueService);

  appelsList: Appel[] = [];
  patientsList: any[] = [];
  loading = false;
  showModal = false;
  editingItem: Appel | null = null;
  message = '';

  form = this.fb.group({
    patient: [null as number | null, Validators.required],
    date_appel: ['', Validators.required],
    statut: ['present', Validators.required],
    motif_absence: [''],
    notes: [''],
    rendez_vous: [null]
  });

  ngOnInit(): void {
    this.loadAppels();
    this.loadPatients();
  }

  loadAppels(): void {
    this.loading = true;
    this.appelsService.lister().subscribe({
      next: (data: Appel[]) => {
        this.appelsList = data;
        this.loading = false;
      },
      error: (err: any) => {
        console.error('Erreur lors du chargement des appels:', err);
        this.message = 'Impossible de charger les appels';
        this.loading = false;
      }
    });
  }

  loadPatients(): void {
    this.patientsService.lister().subscribe({
      next: (data: any[]) => {
        this.patientsList = data;
      },
      error: (err: any) => {
        console.error('Erreur lors du chargement des patients:', err);
      }
    });
  }

  openModal(item?: Appel): void {
    this.editingItem = item || null;
    if (item) {
      this.form.patchValue({
        patient: item.patient,
        date_appel: item.date_appel,
        statut: item.statut,
        motif_absence: item.motif_absence,
        notes: item.notes,
        rendez_vous: null
      });
    } else {
      this.form.reset({
        patient: null,
        date_appel: '',
        statut: 'present',
        motif_absence: '',
        notes: '',
        rendez_vous: null
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
    
    // Construire l'objet de données avec le format correct
    const cleanData: any = {
      patient: Number(formData.patient),
      statut: formData.statut,
      notes_appel: formData.notes || ''
    };

    // Convertir la date au format YYYY-MM-DD
    if (formData.date_appel) {
      const date = new Date(formData.date_appel);
      cleanData.date_appel = date.toISOString().split('T')[0];
    }

    // N'inclure motif_absence que si présent
    if (formData.motif_absence) {
      cleanData.motif_absence = formData.motif_absence;
    }

    // N'inclure rendez_vous que si une valeur est présente
    if (formData.rendez_vous) {
      cleanData.rendez_vous = Number(formData.rendez_vous);
    }

    console.log('DEBUG: Données envoyées pour appel:', JSON.stringify(cleanData, null, 2));

    const request = this.editingItem
      ? this.appelsService.modifier(this.editingItem.id, cleanData)
      : this.appelsService.creer(cleanData);

    request.subscribe({
      next: () => {
        this.message = this.editingItem ? 'Appel modifié avec succès' : 'Appel créé avec succès';
        this.closeModal();
        this.loadAppels();
      },
      error: (err: any) => {
        console.error('Erreur lors de la sauvegarde:', err);
        console.error('Détail erreur:', JSON.stringify(err?.error, null, 2));
        this.message = `Erreur lors de la sauvegarde de l'appel: ${err?.error?.detail || 'Vérifiez les données'}`;
      }
    });
  }

  delete(item: Appel): void {
    this.dialogueService.confirmer({
      titre: 'Confirmation de suppression',
      message: `Êtes-vous sûr de vouloir supprimer cet appel du ${item.date_appel} ?`,
      boutonOk: 'Supprimer',
      boutonAnnuler: 'Annuler'
    }).subscribe(confirme => {
      if (!confirme) return;
      this.appelsService.supprimer(item.id).subscribe({
        next: () => {
          this.message = 'Appel supprimé avec succès';
          this.loadAppels();
        },
        error: (err: any) => {
          console.error('Erreur lors de la suppression:', err);
          this.dialogueService.erreur({
            titre: 'Erreur',
            message: "Impossible de supprimer l'appel."
          });
        }
      });
    });
  }

  getStatutColor(statut: string): string {
    switch (statut) {
      case 'present': return '#22c55e';
      case 'absent': return '#dc2626';
      case 'retard': return '#f59e0b';
      default: return '#6b7280';
    }
  }

  getStatutLabel(statut: string): string {
    switch (statut) {
      case 'present': return 'Présent';
      case 'absent': return 'Absent';
      case 'retard': return 'En retard';
      default: return statut;
    }
  }
}
