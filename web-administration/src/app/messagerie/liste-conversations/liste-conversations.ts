import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink, Router } from '@angular/router';

import { Conversation, Messagerie } from '../../noyau/services/messagerie';
import { Patients } from '../../noyau/services/patients';
import { Patient } from '../../noyau/services/patients';
import { DialogueService } from '../../noyau/services/dialogue.service';

@Component({
  selector: 'app-liste-conversations',
  imports: [CommonModule, RouterLink, FormsModule],
  templateUrl: './liste-conversations.html',
  styleUrl: './liste-conversations.scss',
})
export class ListeConversations implements OnInit {
  private readonly messagerie = inject(Messagerie);
  private readonly patientsService = inject(Patients);
  private readonly router = inject(Router);
  private readonly dialogueService = inject(DialogueService);
  conversations: Conversation[] = [];
  listePatients: Patient[] = [];
  patientSelectionne: Patient | null = null;
  titre = '';
  contact = '';
  modeEdition = false;
  conversationEnEdition: Conversation | null = null;

  ngOnInit(): void {
    this.charger();
    this.chargerPatients();
  }

  charger(): void {
    this.messagerie.listerConversations().subscribe({
      next: (items) => {
        // Filtrer les conversations selon le rôle de l'utilisateur
        this.conversations = this.filtrerConversationsParPatient(items);
      },
    });
  }

  private filtrerConversationsParPatient(conversations: Conversation[]): Conversation[] {
    const utilisateur = this.obtenirUtilisateurConnecte();
    // Le backend renvoie déjà les conversations autorisées pour l'utilisateur connecté.
    // On garde un filtrage défensif basé sur la participation.
    return conversations.filter((conv) => conv.participants?.includes(utilisateur?.id));
  }

  private obtenirUtilisateurConnecte(): any {
    // Récupérer les informations de l'utilisateur connecté
    const userData = localStorage.getItem('utilisateur');
    return userData ? JSON.parse(userData) : null;
  }

  chargerPatients(): void {
    this.patientsService.lister().subscribe({
      next: (patients) => (this.listePatients = patients),
    });
  }

  creerConversation(): void {
    if (!this.titre.trim()) return;

    if (this.patientSelectionne) {
      this.messagerie
        .creerConversation(this.titre, 'patient', this.patientSelectionne.id)
        .subscribe({
          next: (conversation) => {
            this.titre = '';
            this.patientSelectionne = null;
            this.charger();
            this.router.navigate(['/messagerie/conversation', conversation.id]);
          },
          error: () => {
            this.dialogueService.erreur({
              titre: 'Erreur',
              message: 'Impossible de créer la conversation. Veuillez réessayer.'
            }).subscribe();
          }
        });
      return;
    }

    // Sans patient sélectionné, on crée une conversation interne simple.
    this.messagerie.creerConversation(this.titre, 'interne').subscribe({
      next: (conversation) => {
        this.titre = '';
        this.patientSelectionne = null;
        this.charger();
        this.router.navigate(['/messagerie/conversation', conversation.id]);
      },
      error: () => {
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: 'Impossible de créer la conversation. Veuillez réessayer.'
        }).subscribe();
      }
    });
  }

  demarrerChatPatient(): void {
    if (!this.patientSelectionne) {
      this.dialogueService.erreur({
        titre: 'Erreur',
        message: 'Veuillez sélectionner un patient pour démarrer le chat.'
      }).subscribe();
      return;
    }

    const titre = `Chat avec ${this.patientSelectionne.prenom} ${this.patientSelectionne.nom}`;

    this.messagerie.creerConversation(titre, 'patient', this.patientSelectionne.id).subscribe({
      next: (conversation) => {
        this.titre = '';
        this.patientSelectionne = null;
        this.charger();
        this.router.navigate(['/messagerie/conversation', conversation.id]);
      },
      error: () => {
        this.dialogueService.erreur({
          titre: 'Erreur',
          message: 'Impossible de démarrer le chat. Veuillez réessayer.'
        }).subscribe();
      }
    });
  }

  editerConversation(conversation: Conversation): void {
    this.conversationEnEdition = conversation;
    this.titre = conversation.titre;
    this.modeEdition = true;
  }

  sauvegarderEdition(): void {
    if (!this.conversationEnEdition || !this.titre.trim()) return;
    
    // Note: Cette fonctionnalité nécessiterait un endpoint PUT/PATCH dans le backend
    // Pour l'instant, on simule l'édition
    this.modeEdition = false;
    this.conversationEnEdition = null;
    this.titre = '';
    this.charger();
  }

  annulerEdition(): void {
    this.modeEdition = false;
    this.conversationEnEdition = null;
    this.titre = '';
  }

  enregistrerContact(): void {
    if (!this.contact.trim()) return;
    const deja = JSON.parse(localStorage.getItem('warms_contacts') || '[]') as string[];
    localStorage.setItem('warms_contacts', JSON.stringify([...deja, this.contact]));
    this.contact = '';
  }

  voirHistoriquePatient(conversation: Conversation): void {
    if (!conversation.patient) return;
    
    // Rediriger vers la page du patient avec l'historique médical
    this.router.navigate(['/patients', conversation.patient]);
  }
}

// #EbaJioloLewis
