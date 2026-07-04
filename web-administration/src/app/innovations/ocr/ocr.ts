import { CommonModule } from '@angular/common';
import { Component, ViewChild, ElementRef, Inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DOCUMENT } from '@angular/common';
import { OcrService, OCRResult, ImportCarnetResult } from '../../noyau/services/ocr';

interface ChampCarnet {
  cle: string;
  label: string;
  icone: string;
  requis: boolean;
  type: 'text' | 'date' | 'email' | 'tel';
}

const CHAMPS_CARNET: ChampCarnet[] = [
  { cle: 'prenom',         label: 'Prénom',                          icone: 'bi-person-fill',         requis: true,  type: 'text' },
  { cle: 'nom',            label: 'Nom',                             icone: 'bi-person-vcard-fill',   requis: true,  type: 'text' },
  { cle: 'date_naissance', label: 'Date de naissance (AAAA-MM-JJ)',  icone: 'bi-calendar-heart',      requis: false, type: 'date' },
  { cle: 'sexe',           label: 'Sexe (M / F)',                    icone: 'bi-gender-ambiguous',    requis: false, type: 'text' },
  { cle: 'telephone',      label: 'Téléphone',                       icone: 'bi-telephone-fill',      requis: false, type: 'tel'  },
  { cle: 'email',          label: 'Email',                           icone: 'bi-envelope-fill',       requis: false, type: 'email'},
  { cle: 'adresse',        label: 'Adresse',                         icone: 'bi-geo-alt-fill',        requis: false, type: 'text' },
  { cle: 'groupe_sanguin', label: 'Groupe sanguin',                  icone: 'bi-droplet-half',        requis: false, type: 'text' },
  { cle: 'allergies',      label: 'Allergies',                       icone: 'bi-exclamation-triangle-fill', requis: false, type: 'text' },
];

@Component({
  selector: 'app-ocr',
  imports: [CommonModule, FormsModule],
  templateUrl: './ocr.html',
  styleUrl: './ocr.scss',
})
export class Ocr {
  chargement = false;
  operationEnCours: 'upload' | 'scan' | null = null;
  resultat: OCRResult | null = null;
  nomFichierTraite = '';
  erreur: { titre: string; message: string } | null = null;

  // --- Mode import carnet ---
  modeImport = false;
  donneesImport: Record<string, string> = {};
  importEnCours = false;
  importSucces: { username: string; password: string } | null = null;
  importErreur = '';

  readonly champsCarnet = CHAMPS_CARNET;

  @ViewChild('fileInput') fileInput!: ElementRef<HTMLInputElement>;

  constructor(
    @Inject(DOCUMENT) private document: Document,
    private ocrService: OcrService
  ) {}

  // ---------------------------------------------------------------------------
  // OCR existant
  // ---------------------------------------------------------------------------

  onFileUpload(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.operationEnCours = 'upload';
      this.traiterFichier(input.files[0]);
    }
  }

  clickFileInput(): void {
    if (this.fileInput) {
      this.fileInput.nativeElement.click();
    }
  }

  scannerDocument(): void {
    this.operationEnCours = 'scan';
    const input = this.document.createElement('input');
    input.type = 'file';
    input.accept = 'image/jpeg,image/png,image/tiff';
    input.onchange = (e) => {
      const target = e.target as HTMLInputElement;
      if (target.files && target.files.length > 0) {
        this.traiterFichier(target.files[0]);
      } else {
        this.operationEnCours = null;
      }
    };
    input.click();
  }

  private traiterFichier(file: File): void {
    this.chargement = true;
    this.resultat = null;
    this.erreur = null;
    this.modeImport = false;
    this.importSucces = null;
    this.nomFichierTraite = file.name;

    this.ocrService.extraireTexte(file).subscribe({
      next: (result) => {
        this.resultat = result;
        this.chargement = false;
        this.operationEnCours = null;
      },
      error: (error) => this.gererErreurOCR(error),
    });
  }

  private gererErreurOCR(error: any): void {
    this.chargement = false;
    this.operationEnCours = null;
    if (error.status === 503) {
      this.erreur = {
        titre: 'OCR indisponible',
        message: error.error?.detail || "Le moteur OCR n'est pas installé ou accessible.",
      };
      return;
    }
    if (error.status === 400) {
      this.erreur = { titre: 'Document invalide', message: 'Format de fichier invalide ou document illisible.' };
      return;
    }
    if (error.status === 413) {
      this.erreur = { titre: 'Fichier trop volumineux', message: 'Taille maximale acceptée : 10 Mo.' };
      return;
    }
    this.erreur = {
      titre: 'Erreur de traitement',
      message: error.error?.detail || 'Une erreur inattendue est survenue lors du traitement OCR.',
    };
  }

  fermerResultat(): void {
    this.resultat = null;
    this.nomFichierTraite = '';
    this.modeImport = false;
    this.importSucces = null;
    this.importErreur = '';
  }

  fermerErreur(): void {
    this.erreur = null;
  }

  get pourcentageConfiance(): number {
    return Math.round((this.resultat?.confiance ?? 0) * 100);
  }

  get niveauConfiance(): 'haute' | 'moyenne' | 'faible' {
    const p = this.pourcentageConfiance;
    if (p >= 75) return 'haute';
    if (p >= 45) return 'moyenne';
    return 'faible';
  }

  get champsStructures(): { label: string; valeur: string }[] {
    const d = this.resultat?.donnees_structurees;
    if (!d) return [];
    const map: [string, string | undefined][] = [
      ['Prénom',           d.prenom],
      ['Nom',              d.nom],
      ['Date de naissance',d.date_naissance],
      ['Sexe',             d.sexe],
      ['Téléphone',        d.telephone],
      ['Email',            d.email],
      ['Adresse',          d.adresse],
      ['Groupe sanguin',   d.groupe_sanguin],
      ['Allergies',        d.allergies],
    ];
    return map.filter(([, v]) => !!v).map(([label, valeur]) => ({ label, valeur: valeur! }));
  }

  // ---------------------------------------------------------------------------
  // Import carnet patient
  // ---------------------------------------------------------------------------

  lancerImport(): void {
    this.modeImport = true;
    this.importSucces = null;
    this.importErreur = '';

    // Pré-remplir depuis le backend + parsing regex du texte brut
    const d = this.resultat?.donnees_structurees ?? {};
    const parseExtra = this._parseTexteCarnet(this.resultat?.texte_extrait ?? '');

    this.donneesImport = {};
    for (const champ of this.champsCarnet) {
      const val = (d as Record<string, string>)[champ.cle] ?? parseExtra[champ.cle] ?? '';
      this.donneesImport[champ.cle] = val;
    }
  }

  annulerImport(): void {
    this.modeImport = false;
    this.importSucces = null;
    this.importErreur = '';
  }

  soumettreImport(): void {
    const prenom = (this.donneesImport['prenom'] ?? '').trim();
    const nom    = (this.donneesImport['nom']    ?? '').trim();

    if (!prenom || !nom) {
      this.importErreur = 'Le prénom et le nom sont obligatoires.';
      return;
    }

    this.importEnCours = true;
    this.importErreur = '';

    // Filtrer les champs vides
    const payload: Record<string, string> = {};
    for (const [cle, val] of Object.entries(this.donneesImport)) {
      const v = (val ?? '').trim();
      if (v) payload[cle] = v;
    }

    this.ocrService.importerCarnet(payload).subscribe({
      next: (res: ImportCarnetResult) => {
        this.importEnCours = false;
        const ids = res.identifiants_patient;
        if (ids) {
          this.importSucces = { username: ids.username, password: ids.password };
        } else {
          this.importSucces = { username: '—', password: '—' };
        }
      },
      error: (err: any) => {
        this.importEnCours = false;
        const errData = err?.error;
        if (typeof errData === 'object' && errData !== null) {
          this.importErreur = Object.values(errData).flat().join(' ');
        } else {
          this.importErreur = errData?.detail ?? 'Erreur lors de la création du patient.';
        }
      },
    });
  }

  get nbChampsExtraits(): number {
    return Object.values(this.donneesImport).filter(v => (v ?? '').trim().length > 0).length;
  }

  get champsMissingImport(): ChampCarnet[] {
    return this.champsCarnet.filter(c => !(this.donneesImport[c.cle] ?? '').trim());
  }

  // Parsing client-side du texte brut pour les champs non fournis par le backend
  private _parseTexteCarnet(texte: string): Record<string, string> {
    const out: Record<string, string> = {};

    // Groupe sanguin
    const gsM = texte.match(/\b(AB[+\-]|A[+\-]|B[+\-]|O[+\-])\b/);
    if (gsM) out['groupe_sanguin'] = gsM[1];

    // Sexe
    const sexeM = texte.match(/[Ss]exe\s*[:\-]?\s*(M(?:asculin)?|F(?:[eé]minin)?|\bH\b)/);
    if (sexeM) out['sexe'] = /^[Ff]/.test(sexeM[1]) ? 'F' : 'M';

    // Allergies
    const allerM = texte.match(/[Aa]llergies?\s*[:\-]?\s*(.{2,100}?)(?=\n[A-Z]|\n\n|$)/);
    if (allerM) {
      const v = allerM[1].trim();
      if (v && !/^(?:aucune?|n[eé]ant|rAS|\/|-)$/i.test(v)) out['allergies'] = v;
    }

    // Date de naissance (jj/mm/aaaa → aaaa-mm-jj si non fournie par le backend)
    const dateM = texte.match(/(?:[Nn][ée]\(e\)\s+le|[Dd]ate\s+de\s+naissance\s*[:\-]?\s*)(\d{2}[\/\-\.]\d{2}[\/\-\.]\d{4})/);
    if (dateM) {
      const parts = dateM[1].split(/[\/\-\.]/);
      if (parts.length === 3) out['date_naissance'] = `${parts[2]}-${parts[1].padStart(2,'0')}-${parts[0].padStart(2,'0')}`;
    }

    return out;
  }
}

// #EbaJioloLewis
