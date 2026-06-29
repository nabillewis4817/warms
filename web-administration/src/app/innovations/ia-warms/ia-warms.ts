import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { Nl2brPipe } from './nl2br.pipe';
import {
  ActionAssistant,
  WarmsIAService,
} from '../../noyau/services/warms-ia';
import { ThemeService } from '../../noyau/services/theme';

interface MessageChat {
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
  actionEnAttente?: ActionAssistant;
  actionTraitee?: boolean;
}

// Web Speech API : pas de types officiels dans le DOM lib d'Angular/TS pour
// SpeechRecognition (encore préfixé "webkit" dans Chrome/Edge) — on déclare
// le strict minimum utilisé ici plutôt que d'importer un paquet de types.
interface SpeechRecognitionEvent extends Event {
  results: { 0: { transcript: string } }[];
}
interface SpeechRecognitionLike extends EventTarget {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  start(): void;
  stop(): void;
  onresult: ((event: SpeechRecognitionEvent) => void) | null;
  onerror: ((event: Event) => void) | null;
  onend: (() => void) | null;
}

@Component({
  selector: 'app-ia-warms',
  imports: [CommonModule, ReactiveFormsModule, Nl2brPipe],
  templateUrl: './ia-warms.html',
  styleUrl: './ia-warms.scss',
})
export class IaWarms implements OnInit {
  form: any;

  messages: MessageChat[] = [];

  chargement = false;

  // Vocal
  readonly reconnaissanceVocaleDisponible: boolean;
  ecouteEnCours = false;
  lectureVocaleActive = false;
  private reconnaissance: SpeechRecognitionLike | null = null;

  constructor(
    private fb: FormBuilder,
    private warmsIAService: WarmsIAService,
    private router: Router,
    private themeService: ThemeService
  ) {
    this.form = this.fb.group({
      message: ['', Validators.required],
    });

    const SpeechRecognitionCtor: any =
      (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    this.reconnaissanceVocaleDisponible = !!SpeechRecognitionCtor;
    if (SpeechRecognitionCtor) {
      this.reconnaissance = new SpeechRecognitionCtor();
      this.reconnaissance!.lang = 'fr-FR';
      this.reconnaissance!.continuous = false;
      this.reconnaissance!.interimResults = false;
    }
  }

  ngOnInit(): void {
    this.messages.push({
      role: 'assistant',
      content:
        " Bonjour ! Je suis Wams, votre assistant médical intelligent. Je peux discuter avec vous, et aussi agir directement dans l'application sur demande (avec votre confirmation) :\n\n" +
        '• « Ouvre le dossier du patient Dupont »\n' +
        '• « Crée le patient Lucas Martin »\n' +
        '• « Change le thème en sombre »\n' +
        '• « Quelles sont les allergies de Mackenzie ? »\n' +
        '• « Ouvre la page consultations »\n\n' +
        "Vous pouvez aussi me parler avec le micro. Comment puis-je vous aider aujourd'hui ?",
      timestamp: new Date(),
    });
  }

  envoyerMessage(): void {
    if (this.form.invalid || this.chargement) return;

    const message = this.form.value.message?.trim();
    if (!message) return;

    this.messages.push({ role: 'user', content: message, timestamp: new Date() });
    this.chargement = true;
    this.form.reset();

    this.warmsIAService.envoyerCommande(message).subscribe({
      next: (reponse) => {
        this.chargement = false;
        if (reponse.type === 'reponse') {
          this.ajouterReponseAssistant(reponse.texte);
        } else if (reponse.type === 'confirmation') {
          this.ajouterReponseAssistant(reponse.description, reponse.action);
        } else {
          this.appliquerResultat(reponse);
        }
      },
      error: (error) => {
        this.chargement = false;
        this.ajouterReponseAssistant(this.messageErreur(error));
      },
    });
  }

  /** Le practicien confirme l'action proposée par l'assistant : on l'exécute réellement. */
  confirmerAction(message: MessageChat): void {
    if (!message.actionEnAttente || message.actionTraitee) return;
    message.actionTraitee = true;
    this.chargement = true;

    this.warmsIAService.confirmerAction(message.actionEnAttente).subscribe({
      next: (reponse) => {
        this.chargement = false;
        if (reponse.type === 'resultat') {
          this.appliquerResultat(reponse);
        }
      },
      error: (error) => {
        this.chargement = false;
        this.ajouterReponseAssistant(this.messageErreur(error));
      },
    });
  }

  annulerAction(message: MessageChat): void {
    message.actionTraitee = true;
    this.ajouterReponseAssistant("D'accord, je n'effectue pas cette action.");
  }

  /** Applique le résultat d'une action exécutée : message + effet réel (navigation, thème...). */
  private appliquerResultat(reponse: { succes: boolean; message: string; effet?: { type: string; chemin?: string; mode?: 'clair' | 'sombre' } }): void {
    this.ajouterReponseAssistant(reponse.message);

    const effet = reponse.effet;
    if (!effet) return;

    if (effet.type === 'naviguer' && effet.chemin) {
      this.router.navigateByUrl(effet.chemin);
    } else if (effet.type === 'changer_theme' && effet.mode) {
      this.themeService.appliquer(effet.mode === 'sombre');
    }
  }

  private ajouterReponseAssistant(texte: string, actionEnAttente?: ActionAssistant): void {
    this.messages.push({
      role: 'assistant',
      content: texte,
      timestamp: new Date(),
      actionEnAttente,
    });
    if (this.lectureVocaleActive) {
      this.lireAVoixHaute(texte);
    }
  }

  private messageErreur(error: any): string {
    if (error.status === 401) return 'Veuillez vous reconnecter et réessayer.';
    if (error.status === 403) return "Vous n'avez pas les permissions nécessaires pour cette action.";
    if (error.status === 500) return 'Le serveur rencontre des difficultés. Veuillez réessayer plus tard.';
    if (error.status === 0) return 'Impossible de contacter le serveur. Vérifiez votre connexion.';
    return `Erreur ${error.status} : ${error.message || 'erreur inconnue'}.`;
  }

  // ==================== VOCAL ====================

  basculerEcoute(): void {
    if (!this.reconnaissance) return;
    if (this.ecouteEnCours) {
      this.reconnaissance.stop();
      return;
    }

    this.reconnaissance.onresult = (event: SpeechRecognitionEvent) => {
      const transcription = event.results[0][0].transcript;
      this.form.patchValue({ message: transcription });
      this.envoyerMessage();
    };
    this.reconnaissance.onerror = () => (this.ecouteEnCours = false);
    this.reconnaissance.onend = () => (this.ecouteEnCours = false);

    this.ecouteEnCours = true;
    this.reconnaissance.start();
  }

  basculerLectureVocale(): void {
    this.lectureVocaleActive = !this.lectureVocaleActive;
    if (!this.lectureVocaleActive) {
      window.speechSynthesis?.cancel();
    }
  }

  private lireAVoixHaute(texte: string): void {
    if (!window.speechSynthesis) return;
    window.speechSynthesis.cancel();
    const enonce = new SpeechSynthesisUtterance(texte.replace(/[•\n]/g, ' '));
    enonce.lang = 'fr-FR';
    window.speechSynthesis.speak(enonce);
  }

  trackMessageId(index: number): number {
    return index;
  }

  suggestionClick(message: string): void {
    this.form.patchValue({ message });
    this.envoyerMessage();
  }
}
