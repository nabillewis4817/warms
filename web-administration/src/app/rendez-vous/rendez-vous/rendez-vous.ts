import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';

import { RendezVousService, RendezVous } from '../../noyau/services/rendez-vous';
import { Patients } from '../../noyau/services/patients';

@Component({
  selector: 'app-rendez-vous',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './rendez-vous.html',
  styleUrl: './rendez-vous.scss',
})
export class RendezVousComponent implements OnInit {
  private readonly rendezVousService = inject(RendezVousService);
  private readonly patientsService = inject(Patients);
  private readonly fb = inject(FormBuilder);
  private readonly router = inject(Router);

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
    motif: ['', Validators.required],
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
      next: () => {
        this.message = this.editingItem ? 'Rendez-vous modifié avec succès' : 'Rendez-vous créé avec succès';
        this.closeModal();
        this.loadRendezVous();
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
    if (confirm(`Êtes-vous sûr de vouloir supprimer le rendez-vous du ${item.date_heure} ?`)) {
      this.rendezVousService.supprimer(item.id).subscribe({
        next: () => {
          this.message = 'Rendez-vous supprimé avec succès';
          this.loadRendezVous();
        },
        error: (err) => {
          console.error('Erreur lors de la suppression:', err);
          this.message = 'Erreur lors de la suppression du rendez-vous';
        }
      });
    }
  }

  getStatutColor(statut: string): string {
    switch (statut) {
      case 'programme': return '#28a745';
      case 'en_cours': return '#ffc107';
      case 'termine': return '#6c757d';
      case 'annule': return '#dc3545';
      default: return '#6c757d';
    }
  }

  getStatutLabel(statut: string): string {
    switch (statut) {
      case 'programme': return 'Programmé';
      case 'en_cours': return 'En cours';
      case 'termine': return 'Terminé';
      case 'annule': return 'Annulé';
      default: return statut;
    }
  }
}
