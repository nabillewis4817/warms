import { CommonModule } from '@angular/common';
import { Component, OnInit, OnDestroy, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { Subscription, interval } from 'rxjs';

import { Conversation, Messagerie } from '../../noyau/services/messagerie';
import { Patient, Patients } from '../../noyau/services/patients';
import { Personnel, PersonnelService } from '../../noyau/services/personnel.service';
import { DialogueService } from '../../noyau/services/dialogue.service';

type ModeCreation = 'patient' | 'equipe';

@Component({
  selector: 'app-liste-conversations',
  imports: [CommonModule, FormsModule],
  templateUrl: './liste-conversations.html',
  styleUrl: './liste-conversations.scss',
})
export class ListeConversations implements OnInit, OnDestroy {
  private readonly messagerie = inject(Messagerie);
  private readonly patientsService = inject(Patients);
  private readonly personnelService = inject(PersonnelService);
  private readonly router = inject(Router);
  private readonly dialogueService = inject(DialogueService);

  conversations: Conversation[] = [];
  conversationsFiltrees: Conversation[] = [];
  termeRecherche = '';

  listePatients: Patient[] = [];
  listePersonnel: Personnel[] = [];

  afficherCreation = false;
  modeCreation: ModeCreation = 'patient';
  patientSelectionne: Patient | null = null;
  participantsSelectionnes: number[] = [];
  titrePersonnalise = '';
  creationEnCours = false;

  chargement = false;
  private rafraichissement: Subscription | null = null;

  ngOnInit(): void {
    this.charger();
    this.chargerPatients();
    this.chargerPersonnel();
    this.rafraichissement = interval(20000).subscribe(() => this.charger(true));
  }

  ngOnDestroy(): void {
    this.rafraichissement?.unsubscribe();
  }

  charger(silencieux = false): void {
    if (!silencieux) this.chargement = true;
    this.messagerie.listerConversations().subscribe({
      next: (items) => {
        this.conversations = [...items].sort(
          (a, b) => new Date(b.modifie_le).getTime() - new Date(a.modifie_le).getTime()
        );
        this.appliquerFiltre();
        this.chargement = false;
      },
      error: () => (this.chargement = false),
    });
  }

  onRechercheChange(): void {
    this.appliquerFiltre();
  }

  private appliquerFiltre(): void {
    const terme = this.termeRecherche.trim().toLowerCase();
    this.conversationsFiltrees = !terme
      ? this.conversations
      : this.conversations.filter((c) =>
          [c.titre, c.patient_nom, ...(c.participants_info?.map((p) => p.nom) ?? [])]
            .filter(Boolean)
            .some((champ) => String(champ).toLowerCase().includes(terme))
        );
  }

  chargerPatients(): void {
    this.patientsService.lister().subscribe({
      next: (patients) => (this.listePatients = patients),
    });
  }

  chargerPersonnel(): void {
    this.personnelService.getPersonnel().subscribe({
      next: (personnel) => (this.listePersonnel = personnel.filter((p) => p.role?.toLowerCase() !== 'patient')),
    });
  }

  ouvrirPanneauCreation(mode: ModeCreation): void {
    this.modeCreation = mode;
    this.afficherCreation = true;
    this.patientSelectionne = null;
    this.participantsSelectionnes = [];
    this.titrePersonnalise = '';
  }

  fermerPanneauCreation(): void {
    this.afficherCreation = false;
  }

  toggleParticipant(id: number): void {
    const index = this.participantsSelectionnes.indexOf(id);
    if (index >= 0) {
      this.participantsSelectionnes.splice(index, 1);
    } else {
      this.participantsSelectionnes.push(id);
    }
  }

  get peutCreer(): boolean {
    if (this.modeCreation === 'patient') return !!this.patientSelectionne;
    return this.participantsSelectionnes.length > 0;
  }

  creerConversation(): void {
    if (!this.peutCreer || this.creationEnCours) return;
    this.creationEnCours = true;

    if (this.modeCreation === 'patient' && this.patientSelectionne) {
      const titre = `Chat avec ${this.patientSelectionne.prenom} ${this.patientSelectionne.nom}`;
      this.messagerie.creerConversation(titre, 'patient', this.patientSelectionne.id).subscribe({
        next: (conversation) => this.apresCreation(conversation),
        error: () => this.echecCreation(),
      });
      return;
    }

    const noms = this.listePersonnel
      .filter((p) => this.participantsSelectionnes.includes(p.id))
      .map((p) => `${p.prenom} ${p.nom}`)
      .join(', ');
    const titre = this.titrePersonnalise.trim() || `Discussion avec ${noms}`;

    this.messagerie.creerConversation(titre, 'interne', undefined, this.participantsSelectionnes).subscribe({
      next: (conversation) => this.apresCreation(conversation),
      error: () => this.echecCreation(),
    });
  }

  private apresCreation(conversation: Conversation): void {
    this.creationEnCours = false;
    this.afficherCreation = false;
    this.charger();
    this.router.navigate(['/messagerie/conversation', conversation.id]);
  }

  private echecCreation(): void {
    this.creationEnCours = false;
    this.dialogueService
      .erreur({ titre: 'Erreur', message: 'Impossible de créer la conversation. Veuillez réessayer.' })
      .subscribe();
  }

  ouvrirConversation(conversation: Conversation): void {
    this.router.navigate(['/messagerie/conversation', conversation.id]);
  }

  voirDossierPatient(conversation: Conversation, event: Event): void {
    event.stopPropagation();
    if (!conversation.patient) return;
    this.router.navigate(['/patients', conversation.patient, 'dossier']);
  }

  obtenirInitiale(conversation: Conversation): string {
    const source = conversation.patient_nom || conversation.titre || '?';
    return source.charAt(0).toUpperCase();
  }

  obtenirApercu(conversation: Conversation): string {
    if (!conversation.dernier_message) return 'Aucun message pour le moment';
    return conversation.dernier_message.length > 60
      ? conversation.dernier_message.slice(0, 60) + '…'
      : conversation.dernier_message;
  }
}

// #EbaJioloLewis
