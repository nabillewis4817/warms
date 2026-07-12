import { CommonModule } from '@angular/common';
import { Component, ViewChild, ElementRef, Inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DOCUMENT } from '@angular/common';
import { OcrService, OCRResult, ImportCarnetResult } from '../../noyau/services/ocr';
import { PersonnelService, PersonnelCompte } from '../../noyau/services/personnel.service';

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
  praticienChoisi: number | null = null;
  praticienNomOcr = '';
  praticiens: PersonnelCompte[] = [];

  readonly champsCarnet = CHAMPS_CARNET;

  @ViewChild('fileInput') fileInput!: ElementRef<HTMLInputElement>;

  constructor(
    @Inject(DOCUMENT) private document: Document,
    private ocrService: OcrService,
    private personnelService: PersonnelService,
  ) {
    this.personnelService.lister().subscribe({
      next: (liste) => {
        this.praticiens = liste.filter(p => p.role === 'chirurgien_dentiste' && p.is_active);
      },
    });
  }

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
      ['Praticien (détecté)', (d as any).praticien_nom],
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
    this.praticienChoisi = null;

    // Pré-remplir depuis le backend + parsing regex du texte brut
    const d = this.resultat?.donnees_structurees ?? {};
    const parseExtra = this._parseTexteCarnet(this.resultat?.texte_extrait ?? '');

    this.donneesImport = {};
    for (const champ of this.champsCarnet) {
      const val = (d as Record<string, string>)[champ.cle] ?? parseExtra[champ.cle] ?? '';
      this.donneesImport[champ.cle] = val;
    }

    // Nom du praticien extrait par l'OCR (hint pour l'utilisateur)
    this.praticienNomOcr = (d as any)['praticien_nom'] ?? parseExtra['praticien_nom'] ?? '';
  }

  annulerImport(): void {
    this.modeImport = false;
    this.importSucces = null;
    this.importErreur = '';
    this.praticienChoisi = null;
    this.praticienNomOcr = '';
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
    const payload: Record<string, string | number> = {};
    for (const [cle, val] of Object.entries(this.donneesImport)) {
      const v = (val ?? '').trim();
      if (v) payload[cle] = v;
    }
    if (this.praticienChoisi) {
      payload['praticien_referent'] = this.praticienChoisi;
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

  // Parsing client-side du texte brut — même logique que le backend Python.
  // Sert de filet de sécurité pour les champs non extraits par le backend.
  private _parseTexteCarnet(texte: string): Record<string, string> {
    const out: Record<string, string> = {};

    // Borne de fin : MAJ(2+) suivies optionnellement de "(X)" puis ":" ou "-"
    const STOP = String.raw`(?=\s{1,3}[A-ZÀ-Ÿ]{2}[A-ZÀ-Ÿ\s]{0,30}(?:\([A-Z]+\))?\s*[:\-]|\n\n|$)`;

    const extraire = (labelRx: string): string | null => {
      const rx = new RegExp(
        `(?:^|\\n|\\s)(?:${labelRx})\\s*[:\\-]\\s*([^\\n:\\{\\}]{1,120}?)${STOP}`,
        'im'
      );
      const m = texte.match(rx);
      if (!m) return null;
      const v = m[1].replace(/\s{3,}/g, ' ').trim();
      return v.length >= 1 ? v : null;
    };

    // NOM
    const nom = extraire(String.raw`NOM`);
    if (nom) {
      const nomPropre = nom.split(/\s{2,}/)[0].trim();
      if (nomPropre.length >= 2) out['nom'] = nomPropre.toUpperCase();
    }

    // PRÉNOM(S)
    const prenom = extraire(String.raw`PR[EÉ]NOM\(?S?\)?`);
    if (prenom) {
      const prenomPropre = prenom.split(/\s{2,}/)[0].trim();
      if (prenomPropre.length >= 2) out['prenom'] = prenomPropre;
    }

    // DATE DE NAISSANCE / NÉ(E) LE
    const dateM = texte.match(
      /(?:DATE\s+DE\s+NAISSANCE|N[EÉ]E?\s+LE|DDN)\s*[:\-]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{4})/i
    );
    if (dateM) {
      const parts = dateM[1].split(/[\/\-\.]/);
      if (parts.length === 3)
        out['date_naissance'] = `${parts[2]}-${parts[1].padStart(2,'0')}-${parts[0].padStart(2,'0')}`;
    }

    // SEXE
    const sexeM = texte.match(/SEXE\s*[:\-]\s*(M(?:asculin)?|F(?:[eé]minin)?)/i);
    if (sexeM) out['sexe'] = /^[Ff]/i.test(sexeM[1]) ? 'F' : 'M';

    // TÉLÉPHONE
    const telM = texte.match(
      /T[EÉ]L(?:[EÉ]PHONE?)?\s*[:\-]\s*(\+?(?:237|33|229|225|221|228|226|223|224|227)\s?\d[\d\s]{5,13}|\b0\d{9}\b)/i
    );
    if (telM) {
      const tel = telM[1].replace(/\s/g, '');
      if (tel.length >= 8) out['telephone'] = tel;
    } else {
      const telFallback = texte.match(/(\+?(?:237|33|229|225|221|228|226|223|224|227)\s?\d[\d\s]{5,13})/);
      if (telFallback) {
        const tel = telFallback[1].replace(/\s/g, '');
        if (tel.length >= 8) out['telephone'] = tel;
      }
    }

    // EMAIL (déjà robuste, on le garde en fallback)
    const emailM = texte.match(/[\w.\-]+@[\w.\-]+\.\w{2,}/);
    if (emailM) out['email'] = emailM[0].toLowerCase();

    // GROUPE SANGUIN
    const gsM = texte.match(/\b(AB[+\-]|A[+\-]|B[+\-]|O[+\-])\b/);
    if (gsM) out['groupe_sanguin'] = gsM[1];

    // ADRESSE
    const adresse = extraire(String.raw`ADRESSE`);
    if (adresse && adresse.length >= 5) out['adresse'] = adresse;

    // ALLERGIES — on rejette les valeurs trop courtes ou manifestement du bruit OCR
    const allergies = extraire(String.raw`ALLERGI[EÈ]S?`);
    if (allergies) {
      const propre = allergies.split(/\s{2,}/)[0].trim();
      if (
        propre.length >= 3 &&
        !/^(?:aucune?|n[eé]ant|RAS|\/|-|[A-Z]{5,})$/i.test(propre) &&
        // Rejeter le bruit OCR : séquences de lettres majuscules sans voyelle
        !/^[^aeiouyAEIOUYaeiouéèàù]{4,}$/.test(propre)
      ) {
        out['allergies'] = propre;
      }
    }

    // PRATICIEN RÉFÉRENT
    const praticienRx = /(?:PRATICIEN|M[EÉ]DECIN\s+TRAITANT|CHIRURGIEN|DENTISTE)\s*[:\-]\s*((?:Dr\.?\s*)?[A-ZÀ-Ÿa-zà-ÿ][A-ZÀ-Ÿa-zà-ÿ\s\.\-]{1,60}?)(?=\s{3,}[A-ZÀÂÉ]|\n|$)/im;
    const praticienM = texte.match(praticienRx);
    if (praticienM) {
      const pv = praticienM[1].trim();
      if (pv.length >= 3) out['praticien_nom'] = pv;
    }

    return out;
  }
}

// #EbaJioloLewis
