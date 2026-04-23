import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Nl2brPipe } from './nl2br.pipe';
import { WarmsIAService, WarmsIARequest, WarmsIAResponse } from '../../noyau/services/warms-ia';

@Component({
  selector: 'app-ia-warms',
  imports: [CommonModule, ReactiveFormsModule, Nl2brPipe],
  templateUrl: './ia-warms.html',
  styleUrl: './ia-warms.scss',
})
export class IaWarms implements OnInit {
  form: any;
  
  messages: Array<{
    role: 'user' | 'assistant';
    content: string;
    timestamp: Date;
  }> = [];

  chargement = false;

  constructor(
    private fb: FormBuilder,
    private warmsIAService: WarmsIAService
  ) {
    this.form = this.fb.group({
      message: ['', Validators.required],
    });
  }

  ngOnInit(): void {
    // Message de bienvenue
    this.messages.push({
      role: 'assistant',
      content: '👋 Bonjour ! Je suis WARMS, votre assistant médical intelligent. Je peux vous aider avec :\n\n• Questions médicales générales\n• Informations sur les traitements\n• Conseils de santé\n• Aide à l\'utilisation de l\'application\n\nComment puis-je vous aider aujourd\'hui ?',
      timestamp: new Date()
    });
  }

  envoyerMessage(): void {
    if (this.form.invalid || this.chargement) return;

    const message = this.form.value.message?.trim();
    if (!message) return;

    // Ajouter le message de l'utilisateur
    this.messages.push({
      role: 'user',
      content: message,
      timestamp: new Date()
    });

    this.chargement = true;
    this.form.reset();

    // Appeler le service WARMS IA
    const request: WarmsIARequest = {
      question: message
    };

    this.warmsIAService.poserQuestion(request).subscribe({
      next: (response: WarmsIAResponse) => {
        this.messages.push({
          role: 'assistant',
          content: response.reponse,
          timestamp: new Date(response.timestamp)
        });
        this.chargement = false;
      },
      error: (error) => {
        console.error('Erreur WARMS IA:', error);
        // Fallback avec réponse locale si le service n'est pas disponible
        this.simulerReponseIA(message);
        this.chargement = false;
      }
    });
  }

  private simulerReponseIA(message: string): void {
    let reponse = '';

    // Réponses basiques basées sur les mots-clés (fallback)
    if (message.toLowerCase().includes('bonjour') || message.toLowerCase().includes('salut')) {
      reponse = 'Bonjour ! Comment puis-je vous aider aujourd\'hui ? 😊';
    } else if (message.toLowerCase().includes('patient')) {
      reponse = 'Pour gérer les patients, vous pouvez utiliser l\'onglet "Patients" dans le menu. Vous pourrez créer, modifier, archiver ou supprimer des patients. Chaque patient a un dossier médical et un code QR d\'accès.';
    } else if (message.toLowerCase().includes('ordonnance')) {
      reponse = 'Les ordonnances sont accessibles depuis l\'onglet "Prescriptions". Vous pouvez créer de nouvelles ordonnances, les modifier et les consulter. Les patients peuvent également voir leurs ordonnances depuis leur application mobile.';
    } else if (message.toLowerCase().includes('rendez-vous')) {
      reponse = 'Les rendez-vous peuvent être gérés depuis l\'onglet "Agenda". Vous pouvez planifier des consultations, modifier les horaires et envoyer des rappels aux patients.';
    } else if (message.toLowerCase().includes('aide')) {
      reponse = 'Voici les principales fonctionnalités de WARMS :\n\n📋 **Gestion des patients** : Création, modification, archivage\n💊 **Prescriptions** : Gestion des ordonnances médicales\n📅 **Agenda** : Planification des rendez-vous\n💬 **Messagerie** : Communication avec les patients\n📸 **OCR** : Numérisation de documents\n🤖 **IA WARMS** : Assistant intelligent (moi !)\n\nBesoin d\'aide spécifique ? N\'hésitez pas à demander !';
    } else if (message.toLowerCase().includes('ocr')) {
      reponse = 'L\'OCR (Reconnaissance Optique de Caractères) permet de numériser automatiquement les documents médicaux. Allez dans l\'onglet "Innovations" → "OCR" pour utiliser cette fonctionnalité. Prenez une photo ou uploadez un document, et WARMS extraira automatiquement les informations.';
    } else {
      reponse = 'Je comprends votre question. Pour l\'instant, je suis en version bêta et j\'apprends continuellement. Pour des questions médicales spécifiques, je vous recommande de consulter un professionnel de santé.\n\nPuis-je vous aider avec autre chose ?';
    }

    this.messages.push({
      role: 'assistant',
      content: reponse,
      timestamp: new Date()
    });
  }

  trackMessageId(index: number): number {
    return index;
  }

  suggestionClick(message: string): void {
    this.form.patchValue({ message });
    this.envoyerMessage();
  }
}
