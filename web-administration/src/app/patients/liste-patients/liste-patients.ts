import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';

import { Patient, Patients } from '../../noyau/services/patients';
import { DialogueService } from '../../noyau/services/dialogue.service';

@Component({
  selector: 'app-liste-patients',
  imports: [CommonModule],
  templateUrl: './liste-patients.html',
  styleUrl: './liste-patients.scss',
})
export class ListePatients implements OnInit {
  private readonly patientsService = inject(Patients);
  private readonly dialogueService = inject(DialogueService);
  patients: Patient[] = [];
  chargement = false;
  editionId: number | null = null;
  actionEnCours: { [key: number]: string } = {};

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.chargement = true;
    this.patientsService.lister().subscribe({
      next: (items) => (this.patients = items),
      complete: () => (this.chargement = false),
    });
  }

  basculerEdition(patient: Patient): void {
    this.editionId = this.editionId === patient.id ? null : patient.id;
  }

  archiver(patient: Patient): void {
    this.dialogueService.confirmer({
      titre: 'Archiver le patient',
      message: `Êtes-vous sûr de vouloir archiver le patient ${patient.prenom} ${patient.nom} ?\n\nLe patient ne sera plus visible dans la liste active mais ses données seront conservées.`,
      boutonOk: 'Archiver',
      boutonAnnuler: 'Annuler'
    }).subscribe(confirme => {
      if (!confirme) return;
      
      this.actionEnCours[patient.id] = 'archivage';
      this.patientsService.archiver(patient.id).subscribe({
        next: () => {
          delete this.actionEnCours[patient.id];
          this.charger();
          this.dialogueService.succes({
            titre: 'Patient archivé',
            message: `Le patient ${patient.prenom} ${patient.nom} a été archivé avec succès.`
          }).subscribe();
        },
        error: () => {
          delete this.actionEnCours[patient.id];
          this.dialogueService.erreur({
            titre: 'Erreur d\'archivage',
            message: 'Une erreur est survenue lors de l\'archivage du patient. Veuillez réessayer.'
          }).subscribe();
        }
      });
    });
  }

  supprimer(patient: Patient): void {
    this.dialogueService.confirmer({
      titre: 'Supprimer le patient',
      message: `Êtes-vous sûr de vouloir supprimer définitivement le patient ${patient.prenom} ${patient.nom} ?\n\nCette action est irréversible ! Toutes les données du patient seront perdues.`,
      boutonOk: 'Supprimer',
      boutonAnnuler: 'Annuler'
    }).subscribe(confirme => {
      if (!confirme) return;
      
      this.actionEnCours[patient.id] = 'suppression';
      this.patientsService.supprimer(patient.id).subscribe({
        next: () => {
          delete this.actionEnCours[patient.id];
          this.charger();
          this.dialogueService.succes({
            titre: 'Patient supprimé',
            message: `Le patient ${patient.prenom} ${patient.nom} a été supprimé définitivement.`
          }).subscribe();
        },
        error: () => {
          delete this.actionEnCours[patient.id];
          this.dialogueService.erreur({
            titre: 'Erreur de suppression',
            message: 'Une erreur est survenue lors de la suppression du patient. Veuillez réessayer.'
          }).subscribe();
        }
      });
    });
  }
}

// #EbaJioloLewis
