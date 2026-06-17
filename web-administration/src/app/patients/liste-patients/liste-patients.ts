import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';

import { Patient, Patients } from '../../noyau/services/patients';
import { DialogueService } from '../../noyau/services/dialogue.service';

type Vue = 'actifs' | 'archives' | 'corbeille';

@Component({
  selector: 'app-liste-patients',
  imports: [CommonModule, FormsModule],
  templateUrl: './liste-patients.html',
  styleUrl: './liste-patients.scss',
})
export class ListePatients implements OnInit {
  private readonly patientsService = inject(Patients);
  private readonly dialogueService = inject(DialogueService);
  private readonly router = inject(Router);

  vue: Vue = 'actifs';
  patients: Patient[] = [];
  patientsFiltres: Patient[] = [];
  termeRecherche = '';
  chargement = false;
  actionEnCours: { [key: number]: string } = {};

  compteurs: Record<Vue, number> = { actifs: 0, archives: 0, corbeille: 0 };

  ngOnInit(): void {
    this.charger();
  }

  changerVue(vue: Vue): void {
    if (this.vue === vue) return;
    this.vue = vue;
    this.termeRecherche = '';
    this.charger();
  }

  charger(): void {
    this.chargement = true;

    if (this.vue === 'corbeille') {
      this.patientsService.listerCorbeille().subscribe({
        next: (items) => {
          this.patients = items;
          this.appliquerFiltre();
          this.compteurs.corbeille = items.length;
        },
        complete: () => (this.chargement = false),
      });
      return;
    }

    this.patientsService.lister(false).subscribe({
      next: (items) => {
        const actifs = items.filter((p) => p.actif !== false);
        const archives = items.filter((p) => p.actif === false);
        this.compteurs.actifs = actifs.length;
        this.compteurs.archives = archives.length;
        this.patients = this.vue === 'actifs' ? actifs : archives;
        this.appliquerFiltre();
      },
      complete: () => (this.chargement = false),
    });
  }

  onRechercheChange(): void {
    this.appliquerFiltre();
  }

  private appliquerFiltre(): void {
    const terme = this.termeRecherche.trim().toLowerCase();
    this.patientsFiltres = !terme
      ? this.patients
      : this.patients.filter((p) =>
          [p.prenom, p.nom, p.telephone, p.email, p.numero_dossier]
            .filter(Boolean)
            .some((champ) => String(champ).toLowerCase().includes(terme))
        );
  }

  obtenirInitiale(patient: Patient): string {
    return (patient.nom?.[0] || patient.prenom?.[0] || '?').toUpperCase();
  }

  nouveauPatient(): void {
    this.router.navigate(['/patients/nouveau']);
  }

  ouvrirDossier(patient: Patient): void {
    this.router.navigate(['/patients', patient.id, 'dossier']);
  }

  archiver(patient: Patient): void {
    this.dialogueService
      .confirmer({
        titre: 'Archiver le patient',
        message: `Archiver ${patient.prenom} ${patient.nom} ?\n\nIl ne sera plus visible dans la liste active mais ses données seront conservées. Vous pourrez le désarchiver à tout moment.`,
        boutonOk: 'Archiver',
        boutonAnnuler: 'Annuler',
      })
      .subscribe((confirme) => {
        if (!confirme) return;
        this.actionEnCours[patient.id] = 'archivage';
        this.patientsService.archiver(patient.id).subscribe({
          next: () => {
            delete this.actionEnCours[patient.id];
            this.charger();
            this.dialogueService
              .succes({ titre: 'Patient archivé', message: `${patient.prenom} ${patient.nom} a été archivé.` })
              .subscribe();
          },
          error: (err) => this.gererErreur(patient.id, err, "Erreur d'archivage", "Archivage refusé ou erreur serveur."),
        });
      });
  }

  desarchiver(patient: Patient): void {
    this.dialogueService
      .confirmer({
        titre: 'Désarchiver le patient',
        message: `Remettre ${patient.prenom} ${patient.nom} dans la liste active ?`,
        boutonOk: 'Désarchiver',
        boutonAnnuler: 'Annuler',
      })
      .subscribe((confirme) => {
        if (!confirme) return;
        this.actionEnCours[patient.id] = 'desarchivage';
        this.patientsService.desarchiver(patient.id).subscribe({
          next: () => {
            delete this.actionEnCours[patient.id];
            this.charger();
            this.dialogueService
              .succes({ titre: 'Patient désarchivé', message: `${patient.prenom} ${patient.nom} est de nouveau actif.` })
              .subscribe();
          },
          error: (err) => this.gererErreur(patient.id, err, 'Erreur', 'Désarchivage refusé ou erreur serveur.'),
        });
      });
  }

  mettreCorbeille(patient: Patient): void {
    this.dialogueService
      .confirmer({
        titre: 'Mettre à la corbeille',
        message: `Déplacer ${patient.prenom} ${patient.nom} vers la corbeille ?\n\nCette action est réversible : vous pourrez le restaurer depuis la corbeille tant qu'il n'est pas supprimé définitivement.`,
        boutonOk: 'Mettre à la corbeille',
        boutonAnnuler: 'Annuler',
      })
      .subscribe((confirme) => {
        if (!confirme) return;
        this.actionEnCours[patient.id] = 'corbeille';
        this.patientsService.mettreCorbeille(patient.id).subscribe({
          next: () => {
            delete this.actionEnCours[patient.id];
            this.charger();
            this.dialogueService
              .succes({ titre: 'Déplacé vers la corbeille', message: `${patient.prenom} ${patient.nom} a été déplacé vers la corbeille.` })
              .subscribe();
          },
          error: (err) => this.gererErreur(patient.id, err, 'Erreur', 'Impossible de mettre ce patient à la corbeille.'),
        });
      });
  }

  restaurer(patient: Patient): void {
    this.dialogueService
      .confirmer({
        titre: 'Restaurer le patient',
        message: `Restaurer ${patient.prenom} ${patient.nom} depuis la corbeille ?`,
        boutonOk: 'Restaurer',
        boutonAnnuler: 'Annuler',
      })
      .subscribe((confirme) => {
        if (!confirme) return;
        this.actionEnCours[patient.id] = 'restauration';
        this.patientsService.restaurerDeCorbeille(patient.id).subscribe({
          next: () => {
            delete this.actionEnCours[patient.id];
            this.charger();
            this.dialogueService
              .succes({ titre: 'Patient restauré', message: `${patient.prenom} ${patient.nom} a été restauré.` })
              .subscribe();
          },
          error: (err) => this.gererErreur(patient.id, err, 'Erreur', 'Impossible de restaurer ce patient.'),
        });
      });
  }

  supprimerDefinitivement(patient: Patient): void {
    this.dialogueService
      .confirmer({
        titre: 'Suppression définitive',
        message: `Supprimer DÉFINITIVEMENT ${patient.prenom} ${patient.nom} ?\n\nCette action est irréversible : son dossier, son historique de consultations et toutes ses données cliniques seront perdus à jamais.`,
        boutonOk: 'Supprimer définitivement',
        boutonAnnuler: 'Annuler',
      })
      .subscribe((confirme) => {
        if (!confirme) return;
        this.actionEnCours[patient.id] = 'suppression';
        this.patientsService.supprimerDefinitivement(patient.id).subscribe({
          next: () => {
            delete this.actionEnCours[patient.id];
            this.charger();
            this.dialogueService
              .succes({ titre: 'Patient supprimé', message: `${patient.prenom} ${patient.nom} a été supprimé définitivement.` })
              .subscribe();
          },
          error: (err) => this.gererErreur(patient.id, err, 'Erreur de suppression', 'Impossible de supprimer définitivement ce patient.'),
        });
      });
  }

  private gererErreur(patientId: number, err: any, titre: string, messageParDefaut: string): void {
    delete this.actionEnCours[patientId];
    const detail = err?.error?.detail;
    const message = typeof detail === 'string' ? detail : messageParDefaut;
    this.dialogueService.erreur({ titre, message }).subscribe();
  }
}

// #EbaJioloLewis
