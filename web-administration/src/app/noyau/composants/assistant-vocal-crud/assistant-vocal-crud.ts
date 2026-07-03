import { CommonModule } from '@angular/common';
import { Component, inject, OnDestroy } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../../environments/environment';
import { Authentification } from '../../services/authentification';

type EtatModal =
  | 'ferme'
  | 'ecoute_commande'
  | 'intro_patient'
  | 'saisie_patient'
  | 'confirmation'
  | 'succes'
  | 'erreur';

type TypeChamp = 'epellation' | 'texte' | 'telephone' | 'date';

interface ChampDef {
  cle: string;
  label: string;
  type: TypeChamp;
  invite: string;
  placeholder: string;
}

interface SpeechRecognitionEvent extends Event {
  results: { [i: number]: { [j: number]: { transcript: string } } };
}
interface SpeechLike extends EventTarget {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  start(): void;
  stop(): void;
  onresult: ((e: SpeechRecognitionEvent) => void) | null;
  onerror: ((e: Event) => void) | null;
  onend: (() => void) | null;
}

const CHAMPS_PATIENT: ChampDef[] = [
  {
    cle: 'prenom', label: 'Prénom', type: 'epellation',
    invite: 'Épelez le prénom lettre par lettre. Dites « terminer » quand c\'est bon.',
    placeholder: 'Prénom du patient',
  },
  {
    cle: 'nom', label: 'Nom de famille', type: 'epellation',
    invite: 'Maintenant, épelez le nom de famille lettre par lettre.',
    placeholder: 'Nom du patient',
  },
  {
    cle: 'telephone', label: 'Téléphone', type: 'telephone',
    invite: 'Dites le numéro de téléphone. Dites « passer » pour ignorer.',
    placeholder: '+241 XX XX XX XX',
  },
  {
    cle: 'date_naissance', label: 'Date de naissance', type: 'date',
    invite: 'Dites la date de naissance. Exemple : « 15 mars 1990 ». Dites « passer » pour ignorer.',
    placeholder: 'JJ/MM/AAAA',
  },
  {
    cle: 'email', label: 'Email', type: 'texte',
    invite: 'Quelle est l\'adresse email ? Dites « passer » pour ignorer.',
    placeholder: 'email@exemple.com',
  },
  {
    cle: 'adresse', label: 'Adresse', type: 'texte',
    invite: 'Dites l\'adresse complète ou « passer » pour terminer.',
    placeholder: 'Adresse du patient',
  },
];

const NATO: Record<string, string> = {
  'alpha': 'A', 'bravo': 'B', 'charlie': 'C', 'delta': 'D', 'echo': 'E',
  'foxtrot': 'F', 'golf': 'G', 'hotel': 'H', 'india': 'I', 'juliet': 'J',
  'kilo': 'K', 'lima': 'L', 'mike': 'M', 'november': 'N', 'oscar': 'O',
  'papa': 'P', 'québec': 'Q', 'romeo': 'R', 'sierra': 'S', 'tango': 'T',
  'uniform': 'U', 'victor': 'V', 'whiskey': 'W', 'x-ray': 'X', 'yankee': 'Y',
  'zulu': 'Z',
};

const MOIS: Record<string, string> = {
  'janvier': '01', 'février': '02', 'mars': '03', 'avril': '04',
  'mai': '05', 'juin': '06', 'juillet': '07', 'août': '08',
  'septembre': '09', 'octobre': '10', 'novembre': '11', 'décembre': '12',
};

@Component({
  selector: 'app-assistant-vocal-crud',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './assistant-vocal-crud.html',
  styleUrl: './assistant-vocal-crud.scss',
})
export class AssistantVocalCrud implements OnDestroy {
  private readonly http = inject(HttpClient);
  readonly auth = inject(Authentification);

  readonly vocaleDisponible: boolean;
  private readonly SpeechCtor: any;
  private recInstance: SpeechLike | null = null;

  etat: EtatModal = 'ferme';
  commandeReconnue = '';
  transcriptEnCours = '';

  // Formulaire patient
  readonly champs = CHAMPS_PATIENT;
  champIndex = 0;
  valeurs: Record<string, string> = {};
  lettresAccumulees = '';
  ecoute = false;
  soumissionEnCours = false;
  messageErreur = '';

  constructor() {
    this.SpeechCtor = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    this.vocaleDisponible = !!this.SpeechCtor;
  }

  // ─── Accesseurs template ───────────────────────────────────────
  get champActuel(): ChampDef {
    return this.champs[this.champIndex];
  }

  get progres(): number {
    return Math.round(((this.champIndex) / this.champs.length) * 100);
  }

  get estDernierChamp(): boolean {
    return this.champIndex === this.champs.length - 1;
  }

  estChampActif(i: number): boolean {
    return i === this.champIndex;
  }

  estChampRempli(cle: string): boolean {
    return !!(this.valeurs[cle]?.trim());
  }

  valeurAffichee(cle: string): string {
    return this.valeurs[cle] ?? '';
  }

  // ─── Ouverture / fermeture ─────────────────────────────────────
  ouvrir(): void {
    if (!this.vocaleDisponible) {
      alert('Reconnaissance vocale non disponible dans ce navigateur. Utilisez Chrome ou Edge.');
      return;
    }
    this.etat = 'ecoute_commande';
    this.commandeReconnue = '';
    this.transcriptEnCours = '';
    this._parler('Bonjour ! Que souhaitez-vous faire ? Dites par exemple : Créer un patient.');
    this._demarrerEcouteCommande();
  }

  fermer(): void {
    this._arreterEcoute();
    window.speechSynthesis?.cancel();
    this.etat = 'ferme';
    this.champIndex = 0;
    this.valeurs = {};
    this.lettresAccumulees = '';
    this.ecoute = false;
    this.soumissionEnCours = false;
    this.messageErreur = '';
    this.transcriptEnCours = '';
    this.commandeReconnue = '';
  }

  // ─── Commande générale ─────────────────────────────────────────
  private _demarrerEcouteCommande(): void {
    this._ecouterUne((transcript) => {
      this.commandeReconnue = transcript;
      if (/patient|malade|nouveau dossier/.test(transcript)) {
        this._lancerCreationPatient();
      } else {
        this._parler('Désolé, je n\'ai pas compris. Dites par exemple : Créer un patient.');
        setTimeout(() => this._demarrerEcouteCommande(), 1500);
      }
    });
  }

  private _lancerCreationPatient(): void {
    this.etat = 'intro_patient';
    this.champIndex = 0;
    this.valeurs = {};
    this.lettresAccumulees = '';
    setTimeout(() => {
      this.etat = 'saisie_patient';
      this._annoncerChamp();
    }, 900);
  }

  // ─── Navigation dans les champs ───────────────────────────────
  private _annoncerChamp(): void {
    const champ = this.champActuel;
    this._parler(champ.invite);
    setTimeout(() => this._ecouterChamp(), 1200);
  }

  private _ecouterChamp(): void {
    const champ = this.champActuel;
    if (champ.type === 'epellation') {
      this.lettresAccumulees = this.valeurs[champ.cle] ?? '';
      this._boucleEpellation();
    } else {
      this._ecouterUne((t) => this._traiterValeur(t));
    }
  }

  private _traiterValeur(transcript: string): void {
    const t = transcript.toLowerCase().trim();
    if (['passer', 'ignorer', 'skip'].includes(t)) {
      this._champSuivant();
      return;
    }
    const champ = this.champActuel;
    if (champ.type === 'date') {
      const date = this._parseDate(t);
      if (date) {
        this.valeurs[champ.cle] = date;
        this._parler(`J'ai noté le ${date}. `);
        setTimeout(() => this._champSuivant(), 900);
      } else {
        this._parler('Je n\'ai pas compris la date. Réessayez ou dites passer.');
        setTimeout(() => this._ecouterUne((t2) => this._traiterValeur(t2)), 800);
      }
    } else {
      this.valeurs[champ.cle] = transcript;
      this._parler(`J'ai noté.`);
      setTimeout(() => this._champSuivant(), 700);
    }
  }

  private _champSuivant(): void {
    if (this.champIndex < this.champs.length - 1) {
      this.champIndex++;
      this._annoncerChamp();
    } else {
      this.etat = 'confirmation';
      this._parler(
        `Récapitulatif : prénom ${this.valeurs['prenom'] ?? '—'}, nom ${this.valeurs['nom'] ?? '—'}. Dites "confirmer" pour enregistrer ou "annuler" pour recommencer.`
      );
      this._ecouterUne((t) => {
        if (/confirm|oui|enregistr|valider/.test(t.toLowerCase())) {
          this._soumettre();
        } else {
          this.champIndex = 0;
          this.valeurs = {};
          this.etat = 'saisie_patient';
          this._annoncerChamp();
        }
      });
    }
  }

  champPrecedent(): void {
    if (this.champIndex > 0) {
      this._arreterEcoute();
      this.champIndex--;
      this._annoncerChamp();
    }
  }

  passerChamp(): void {
    this._arreterEcoute();
    this._champSuivant();
  }

  confirmerEpellation(): void {
    this._arreterEcoute();
    const champ = this.champActuel;
    this.valeurs[champ.cle] = this.lettresAccumulees;
    this._champSuivant();
  }

  corrigerLettre(): void {
    this.lettresAccumulees = this.lettresAccumulees.slice(0, -1);
  }

  // ─── Mode épellation ──────────────────────────────────────────
  private _boucleEpellation(): void {
    this.ecoute = true;
    this._ecouterUne((transcript) => {
      if (!this.ecoute) return;
      const t = transcript.toLowerCase().trim();

      if (['terminer', 'fin', 'ok', 'suivant', 'valider'].includes(t)) {
        const champ = this.champActuel;
        this.valeurs[champ.cle] = this.lettresAccumulees;
        this._arreterEcoute();
        this._parler(`${this.lettresAccumulees}. Compris.`);
        setTimeout(() => this._champSuivant(), 700);
        return;
      }
      if (['effacer', 'supprimer', 'retour', 'annuler dernier'].includes(t)) {
        this.lettresAccumulees = this.lettresAccumulees.slice(0, -1);
      } else if (t === 'espace') {
        this.lettresAccumulees += ' ';
      } else {
        const lettre = this._extraireLettreEpellation(t);
        if (lettre) this.lettresAccumulees += lettre;
      }

      if (this.ecoute) this._boucleEpellation();
    });
  }

  private _extraireLettreEpellation(t: string): string {
    if (NATO[t]) return NATO[t];
    if (t.length === 1 && /[a-zÀ-ÿ]/i.test(t)) return t.toUpperCase();
    // "comme alpha" → extrait "alpha"
    const match = t.match(/comme\s+(\w+)/);
    if (match && NATO[match[1]]) return NATO[match[1]];
    return '';
  }

  // ─── Soumission ────────────────────────────────────────────────
  private _soumettre(): void {
    this.soumissionEnCours = true;
    const payload = {
      prenom: this.valeurs['prenom'] ?? '',
      nom: this.valeurs['nom'] ?? '',
      telephone: this.valeurs['telephone'] ?? '',
      date_naissance: this.valeurs['date_naissance'] ?? '',
      email: this.valeurs['email'] ?? '',
      adresse: this.valeurs['adresse'] ?? '',
      actif: true,
    };
    this.http.post(`${environment.apiBaseUrl}/patients/patients/`, payload).subscribe({
      next: () => {
        this.soumissionEnCours = false;
        this.etat = 'succes';
        this._parler(`Le patient ${payload.prenom} ${payload.nom} a été créé avec succès.`);
      },
      error: (err) => {
        this.soumissionEnCours = false;
        this.etat = 'erreur';
        this.messageErreur = err?.error?.detail ?? 'Une erreur s\'est produite. Vérifiez les données.';
        this._parler('Une erreur s\'est produite. Veuillez vérifier les données et réessayer.');
      },
    });
  }

  soumettreDirect(): void {
    this._soumettre();
  }

  recommencer(): void {
    this.champIndex = 0;
    this.valeurs = {};
    this.lettresAccumulees = '';
    this.etat = 'saisie_patient';
    this._annoncerChamp();
  }

  // ─── Speech API helpers ────────────────────────────────────────
  private _ecouterUne(callback: (transcript: string) => void): void {
    if (!this.SpeechCtor) return;
    const rec: SpeechLike = new this.SpeechCtor();
    rec.lang = 'fr-FR';
    rec.continuous = false;
    rec.interimResults = false;

    rec.onresult = (e: SpeechRecognitionEvent) => {
      const t = (e.results as any)[0][0].transcript.trim();
      this.transcriptEnCours = t;
      callback(t);
    };
    rec.onerror = () => {
      setTimeout(() => { if (this.ecoute || this.etat !== 'ferme') this._ecouterUne(callback); }, 400);
    };
    rec.onend = null;

    this.recInstance = rec;
    try { rec.start(); } catch (_) {}
  }

  private _arreterEcoute(): void {
    this.ecoute = false;
    try { this.recInstance?.stop(); } catch (_) {}
    this.recInstance = null;
  }

  private _parler(texte: string): void {
    if (!window.speechSynthesis) return;
    window.speechSynthesis.cancel();
    const utt = new SpeechSynthesisUtterance(texte);
    utt.lang = 'fr-FR';
    utt.rate = 1.05;
    utt.pitch = 1;
    window.speechSynthesis.speak(utt);
  }

  private _parseDate(t: string): string | null {
    // "15 mars 1990" → "1990-03-15"
    const match = t.match(/(\d{1,2})\s+(\w+)\s+(\d{4})/);
    if (!match) return null;
    const jour = match[1].padStart(2, '0');
    const mois = MOIS[match[2].toLowerCase()];
    if (!mois) return null;
    return `${match[3]}-${mois}-${jour}`;
  }

  ngOnDestroy(): void {
    this._arreterEcoute();
    window.speechSynthesis?.cancel();
  }
}
