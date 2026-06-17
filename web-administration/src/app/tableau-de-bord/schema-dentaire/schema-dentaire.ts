import { Component, Input, Output, EventEmitter, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Patient } from '../../noyau/services/patients';
import { SchemasDentairesService, SchemaSauvegarde } from '../../noyau/services/schemas-dentaires.service';
import { ConditionDentaire, EtatDent, ActePlanifie } from './dental-types';

export type { ConditionDentaire, EtatDent, ActePlanifie } from './dental-types';

export interface InfoDent {
  numero: number;
  nom: string;
  type: 'incisive_centrale' | 'incisive_laterale' | 'canine' | 'premolaire' | 'molaire' | 'sagesse';
  quadrant: 1 | 2 | 3 | 4;
  cx: number;
  cy: number;
  w: number;
  h: number;
}

interface OutilDentaire {
  id: ConditionDentaire;
  libelle: string;
  icone: string;
  couleur: string;
  fondClair: string;
}

const DENTS_DATA: InfoDent[] = [
  // Q1 — maxillaire supérieur droit (à gauche de l'écran)
  { numero: 18, nom: 'Molaire sagesse sup. dr.', type: 'sagesse',           quadrant: 1, cx: 46,  cy: 226, w: 24, h: 24 },
  { numero: 17, nom: '2ème molaire sup. dr.',    type: 'molaire',           quadrant: 1, cx: 87,  cy: 185, w: 28, h: 28 },
  { numero: 16, nom: '1ère molaire sup. dr.',    type: 'molaire',           quadrant: 1, cx: 131, cy: 154, w: 32, h: 32 },
  { numero: 15, nom: '2ème prémolaire sup. dr.', type: 'premolaire',        quadrant: 1, cx: 173, cy: 132, w: 24, h: 24 },
  { numero: 14, nom: '1ère prémolaire sup. dr.', type: 'premolaire',        quadrant: 1, cx: 211, cy: 118, w: 24, h: 24 },
  { numero: 13, nom: 'Canine sup. droite',       type: 'canine',            quadrant: 1, cx: 248, cy: 109, w: 20, h: 30 },
  { numero: 12, nom: 'Incisive lat. sup. dr.',   type: 'incisive_laterale', quadrant: 1, cx: 283, cy: 104, w: 18, h: 28 },
  { numero: 11, nom: 'Incisive cent. sup. dr.',  type: 'incisive_centrale', quadrant: 1, cx: 320, cy: 102, w: 22, h: 30 },
  // Q2 — maxillaire supérieur gauche (à droite de l'écran)
  { numero: 21, nom: 'Incisive cent. sup. ga.',  type: 'incisive_centrale', quadrant: 2, cx: 400, cy: 102, w: 22, h: 30 },
  { numero: 22, nom: 'Incisive lat. sup. ga.',   type: 'incisive_laterale', quadrant: 2, cx: 437, cy: 104, w: 18, h: 28 },
  { numero: 23, nom: 'Canine sup. gauche',       type: 'canine',            quadrant: 2, cx: 472, cy: 109, w: 20, h: 30 },
  { numero: 24, nom: '1ère prémolaire sup. ga.', type: 'premolaire',        quadrant: 2, cx: 509, cy: 118, w: 24, h: 24 },
  { numero: 25, nom: '2ème prémolaire sup. ga.', type: 'premolaire',        quadrant: 2, cx: 547, cy: 132, w: 24, h: 24 },
  { numero: 26, nom: '1ère molaire sup. ga.',    type: 'molaire',           quadrant: 2, cx: 589, cy: 154, w: 32, h: 32 },
  { numero: 27, nom: '2ème molaire sup. ga.',    type: 'molaire',           quadrant: 2, cx: 633, cy: 185, w: 28, h: 28 },
  { numero: 28, nom: 'Molaire sagesse sup. ga.', type: 'sagesse',           quadrant: 2, cx: 674, cy: 226, w: 24, h: 24 },
  // Q4 — mandibule inférieur droit (à gauche de l'écran)
  { numero: 48, nom: 'Molaire sagesse inf. dr.', type: 'sagesse',           quadrant: 4, cx: 46,  cy: 270, w: 24, h: 24 },
  { numero: 47, nom: '2ème molaire inf. dr.',    type: 'molaire',           quadrant: 4, cx: 87,  cy: 311, w: 28, h: 28 },
  { numero: 46, nom: '1ère molaire inf. dr.',    type: 'molaire',           quadrant: 4, cx: 131, cy: 342, w: 32, h: 32 },
  { numero: 45, nom: '2ème prémolaire inf. dr.', type: 'premolaire',        quadrant: 4, cx: 173, cy: 364, w: 24, h: 24 },
  { numero: 44, nom: '1ère prémolaire inf. dr.', type: 'premolaire',        quadrant: 4, cx: 211, cy: 378, w: 24, h: 24 },
  { numero: 43, nom: 'Canine inf. droite',       type: 'canine',            quadrant: 4, cx: 248, cy: 387, w: 20, h: 30 },
  { numero: 42, nom: 'Incisive lat. inf. dr.',   type: 'incisive_laterale', quadrant: 4, cx: 283, cy: 392, w: 18, h: 28 },
  { numero: 41, nom: 'Incisive cent. inf. dr.',  type: 'incisive_centrale', quadrant: 4, cx: 320, cy: 394, w: 22, h: 30 },
  // Q3 — mandibule inférieur gauche (à droite de l'écran)
  { numero: 31, nom: 'Incisive cent. inf. ga.',  type: 'incisive_centrale', quadrant: 3, cx: 400, cy: 394, w: 22, h: 30 },
  { numero: 32, nom: 'Incisive lat. inf. ga.',   type: 'incisive_laterale', quadrant: 3, cx: 437, cy: 392, w: 18, h: 28 },
  { numero: 33, nom: 'Canine inf. gauche',       type: 'canine',            quadrant: 3, cx: 472, cy: 387, w: 20, h: 30 },
  { numero: 34, nom: '1ère prémolaire inf. ga.', type: 'premolaire',        quadrant: 3, cx: 509, cy: 378, w: 24, h: 24 },
  { numero: 35, nom: '2ème prémolaire inf. ga.', type: 'premolaire',        quadrant: 3, cx: 547, cy: 364, w: 24, h: 24 },
  { numero: 36, nom: '1ère molaire inf. ga.',    type: 'molaire',           quadrant: 3, cx: 589, cy: 342, w: 32, h: 32 },
  { numero: 37, nom: '2ème molaire inf. ga.',    type: 'molaire',           quadrant: 3, cx: 633, cy: 311, w: 28, h: 28 },
  { numero: 38, nom: 'Molaire sagesse inf. ga.', type: 'sagesse',           quadrant: 3, cx: 674, cy: 270, w: 24, h: 24 },
];

export const CONDITION_STYLES: Record<ConditionDentaire, { fill: string; stroke: string; label: string; couleur: string }> = {
  sain:       { fill: '#f0fdf4', stroke: '#22c55e', label: 'Sain',               couleur: '#22c55e' },
  carie:      { fill: '#fef2f2', stroke: '#ef4444', label: 'Carie',              couleur: '#ef4444' },
  extraction: { fill: '#f1f5f9', stroke: '#94a3b8', label: 'Extraction',         couleur: '#94a3b8' },
  couronne:   { fill: '#eff6ff', stroke: '#3b82f6', label: 'Couronne',           couleur: '#3b82f6' },
  canal:      { fill: '#fff7ed', stroke: '#f97316', label: 'Traitement de canal', couleur: '#f97316' },
  bridge:     { fill: '#f5f3ff', stroke: '#8b5cf6', label: 'Bridge',             couleur: '#8b5cf6' },
  implant:    { fill: '#ecfeff', stroke: '#06b6d4', label: 'Implant',            couleur: '#06b6d4' },
  fracture:   { fill: '#fff1f2', stroke: '#e11d48', label: 'Fracture',           couleur: '#e11d48' },
  detartrage: { fill: '#fefce8', stroke: '#ca8a04', label: 'Détartrage',         couleur: '#ca8a04' },
  obturation: { fill: '#f8fafc', stroke: '#475569', label: 'Obturation',         couleur: '#475569' },
};

const OUTILS: OutilDentaire[] = [
  { id: 'sain',       libelle: 'Sain',              icone: 'bi-check-circle-fill',  couleur: '#22c55e', fondClair: '#f0fdf4' },
  { id: 'carie',      libelle: 'Carie',             icone: 'bi-exclamation-circle', couleur: '#ef4444', fondClair: '#fef2f2' },
  { id: 'extraction', libelle: 'Extraction',        icone: 'bi-x-circle-fill',      couleur: '#94a3b8', fondClair: '#f1f5f9' },
  { id: 'couronne',   libelle: 'Couronne',          icone: 'bi-shield-fill',        couleur: '#3b82f6', fondClair: '#eff6ff' },
  { id: 'canal',      libelle: 'Traitement canal',  icone: 'bi-tools',              couleur: '#f97316', fondClair: '#fff7ed' },
  { id: 'bridge',     libelle: 'Bridge',            icone: 'bi-link-45deg',         couleur: '#8b5cf6', fondClair: '#f5f3ff' },
  { id: 'implant',    libelle: 'Implant',           icone: 'bi-gear-fill',          couleur: '#06b6d4', fondClair: '#ecfeff' },
  { id: 'fracture',   libelle: 'Fracture',          icone: 'bi-lightning-fill',     couleur: '#e11d48', fondClair: '#fff1f2' },
  { id: 'detartrage', libelle: 'Détartrage',        icone: 'bi-stars',              couleur: '#ca8a04', fondClair: '#fefce8' },
  { id: 'obturation', libelle: 'Obturation',        icone: 'bi-circle-fill',        couleur: '#475569', fondClair: '#f8fafc' },
];

@Component({
  selector: 'app-schema-dentaire',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './schema-dentaire.html',
  styleUrl: './schema-dentaire.scss',
})
export class SchemaDentaire implements OnInit {
  @Input() patient: Patient | null = null;
  @Input() schemaSauvegarde: SchemaSauvegarde | null = null;
  @Output() fermerEvent    = new EventEmitter<void>();
  @Output() ouvrirListeEvent = new EventEmitter<void>();

  private readonly schemasSvc = inject(SchemasDentairesService);

  schemaId: string | null = null;

  readonly dents = DENTS_DATA;
  readonly outils = OUTILS;

  outilSelectionne: ConditionDentaire | null = null;
  dentSelectionnee: InfoDent | null = null;
  modePresentation = false;
  notesDent = '';

  modalSuccesOuvert = false;
  modalResetOuvert = false;
  modalExportOuvert = false;
  statsAuSauvegarde = { traitements: 0, actes: 0 };

  dentsEtat: EtatDent[] = DENTS_DATA.map(d => ({
    numero: d.numero,
    condition: 'sain' as ConditionDentaire,
    notes: '',
  }));

  actesPlanifies: ActePlanifie[] = [];

  ngOnInit(): void {
    if (this.schemaSauvegarde) {
      this.schemaId       = this.schemaSauvegarde.id;
      this.dentsEtat      = this.schemaSauvegarde.dentsEtat.map(e => ({ ...e }));
      this.actesPlanifies = this.schemaSauvegarde.actesPlanifies.map(a => ({ ...a }));
    }
  }

  get dentsMaxillaire(): InfoDent[] {
    return DENTS_DATA.filter(d => d.quadrant === 1 || d.quadrant === 2);
  }

  get dentesMandibule(): InfoDent[] {
    return DENTS_DATA.filter(d => d.quadrant === 3 || d.quadrant === 4);
  }

  get initiales(): string {
    const p = (this.patient?.prenom ?? '').charAt(0).toUpperCase();
    const n = (this.patient?.nom ?? '').charAt(0).toUpperCase();
    return p + n || '??';
  }

  get actesPlanifiesCount(): number {
    return this.actesPlanifies.filter(a => a.statut === 'planifie').length;
  }

  get actesEnCoursCount(): number {
    return this.actesPlanifies.filter(a => a.statut === 'en_cours').length;
  }

  get actesTerminesCount(): number {
    return this.actesPlanifies.filter(a => a.statut === 'termine').length;
  }

  getEtatDent(numero: number): EtatDent {
    return this.dentsEtat.find(e => e.numero === numero)
      ?? { numero, condition: 'sain', notes: '' };
  }

  getConditionFill(numero: number): string {
    return CONDITION_STYLES[this.getEtatDent(numero).condition].fill;
  }

  getConditionStroke(numero: number): string {
    return CONDITION_STYLES[this.getEtatDent(numero).condition].stroke;
  }

  getConditionCouleur(numero: number): string {
    return CONDITION_STYLES[this.getEtatDent(numero).condition].couleur;
  }

  getConditionLabel(numero: number): string {
    return CONDITION_STYLES[this.getEtatDent(numero).condition].label;
  }

  isExtraction(numero: number): boolean {
    return this.getEtatDent(numero).condition === 'extraction';
  }

  isDentSelectionnee(numero: number): boolean {
    return this.dentSelectionnee?.numero === numero;
  }

  getNomDent(dent: InfoDent): string {
    return dent.nom;
  }

  hasMolarDetail(dent: InfoDent): boolean {
    return dent.type === 'molaire' || dent.type === 'sagesse';
  }

  hasPremolarDetail(dent: InfoDent): boolean {
    return dent.type === 'premolaire';
  }

  selectionnerOutil(id: ConditionDentaire): void {
    this.outilSelectionne = this.outilSelectionne === id ? null : id;
  }

  onDentClick(dent: InfoDent): void {
    if (this.outilSelectionne) {
      const etat = this.dentsEtat.find(e => e.numero === dent.numero);
      if (etat) {
        const ancienne = etat.condition;
        etat.condition = this.outilSelectionne;
        if (ancienne !== this.outilSelectionne && this.outilSelectionne !== 'sain') {
          this.ajouterActeTimeline(dent, this.outilSelectionne);
        }
        if (this.outilSelectionne === 'sain') {
          this.actesPlanifies = this.actesPlanifies.filter(a => a.dent !== dent.numero);
        }
      }
    }
    this.dentSelectionnee = dent;
    this.notesDent = this.getEtatDent(dent.numero).notes;
  }

  private ajouterActeTimeline(dent: InfoDent, condition: ConditionDentaire): void {
    const outil = OUTILS.find(o => o.id === condition);
    if (!outil) return;
    const dejaPresent = this.actesPlanifies.find(
      a => a.dent === dent.numero && a.type === condition
    );
    if (!dejaPresent) {
      this.actesPlanifies.push({
        id: `${dent.numero}-${condition}-${Date.now()}`,
        dent: dent.numero,
        type: condition,
        libelle: outil.libelle,
        statut: 'planifie',
      });
    }
  }

  sauvegarderNotes(): void {
    if (!this.dentSelectionnee) return;
    const etat = this.dentsEtat.find(e => e.numero === this.dentSelectionnee!.numero);
    if (etat) etat.notes = this.notesDent;
  }

  avancerStatut(acte: ActePlanifie): void {
    if (acte.statut === 'planifie') acte.statut = 'en_cours';
    else if (acte.statut === 'en_cours') acte.statut = 'termine';
    else acte.statut = 'planifie';
  }

  supprimerActe(id: string): void {
    this.actesPlanifies = this.actesPlanifies.filter(a => a.id !== id);
  }

  getStatutLabel(statut: string): string {
    if (statut === 'planifie') return 'Planifié';
    if (statut === 'en_cours') return 'En cours';
    return 'Terminé';
  }

  getStatutIcon(statut: string): string {
    if (statut === 'planifie') return 'bi-clock';
    if (statut === 'en_cours') return 'bi-arrow-repeat';
    return 'bi-check-circle-fill';
  }

  getOutilActif(): OutilDentaire | null {
    return this.outils.find(o => o.id === this.outilSelectionne) ?? null;
  }

  togglePresentation(): void {
    this.modePresentation = !this.modePresentation;
    this.outilSelectionne = null;
  }

  resetSchema(): void {
    this.modalResetOuvert = true;
  }

  confirmerReset(): void {
    this.dentsEtat = DENTS_DATA.map(d => ({
      numero: d.numero,
      condition: 'sain' as ConditionDentaire,
      notes: '',
    }));
    this.actesPlanifies = [];
    this.dentSelectionnee = null;
    this.outilSelectionne = null;
    this.modalResetOuvert = false;
  }

  sauvegarder(): void {
    this.sauvegarderNotes();
    const traitements = this.dentsEtat.filter(e => e.condition !== 'sain').length;

    // Sauvegarde locale immédiate (sans aperçu)
    const schema = this.schemasSvc.sauvegarder({
      id:             this.schemaId ?? undefined,
      patient:        this.patient!,
      dentsEtat:      this.dentsEtat.map(e => ({ ...e })),
      actesPlanifies: this.actesPlanifies.map(a => ({ ...a })),
      apercu:         '',
      traitements,
    });
    this.schemaId = schema.id;

    // Génération de l'aperçu PNG en arrière-plan, puis mise à jour
    this.genererApercu().then(apercu => {
      if (apercu) {
        this.schemasSvc.sauvegarder({ ...schema, apercu });
      }
    });

    this.statsAuSauvegarde = { traitements, actes: this.actesPlanifies.length };
    this.modalSuccesOuvert = true;
  }

  private genererApercu(): Promise<string> {
    return new Promise(resolve => {
      const svgEl = document.querySelector('.dental-svg') as SVGElement | null;
      if (!svgEl) { resolve(''); return; }
      const clone = svgEl.cloneNode(true) as SVGElement;
      clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
      clone.setAttribute('width', '720');
      clone.setAttribute('height', '498');
      const blob = new Blob([new XMLSerializer().serializeToString(clone)], { type: 'image/svg+xml;charset=utf-8' });
      const url  = URL.createObjectURL(blob);
      const img  = new Image();
      img.onload = () => {
        const canvas = document.createElement('canvas');
        canvas.width  = 720;
        canvas.height = 498;
        const ctx = canvas.getContext('2d')!;
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, 720, 498);
        ctx.drawImage(img, 0, 0, 720, 498);
        URL.revokeObjectURL(url);
        resolve(canvas.toDataURL('image/png', 0.85));
      };
      img.onerror = () => { URL.revokeObjectURL(url); resolve(''); };
      img.src = url;
    });
  }

  ouvrirExport(): void {
    this.modalExportOuvert = true;
  }

  exporter(format: 'png' | 'jpg'): void {
    this.modalExportOuvert = false;
    const svgEl = document.querySelector('.dental-svg') as SVGElement;
    if (!svgEl) return;
    const clone = svgEl.cloneNode(true) as SVGElement;
    clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    clone.setAttribute('width', '720');
    clone.setAttribute('height', '498');
    const svgData = new XMLSerializer().serializeToString(clone);
    const svgBlob = new Blob([svgData], { type: 'image/svg+xml;charset=utf-8' });
    const objectUrl = URL.createObjectURL(svgBlob);
    const img = new Image();
    img.onload = () => {
      const scale = 2;
      const canvas = document.createElement('canvas');
      canvas.width = 720 * scale;
      canvas.height = 498 * scale;
      const ctx = canvas.getContext('2d')!;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.scale(scale, scale);
      ctx.drawImage(img, 0, 0, 720, 498);
      URL.revokeObjectURL(objectUrl);
      const mime = format === 'jpg' ? 'image/jpeg' : 'image/png';
      const a = document.createElement('a');
      a.download = `schema_${this.patient?.nom ?? 'patient'}_${new Date().toISOString().split('T')[0]}.${format}`;
      a.href = canvas.toDataURL(mime, 0.95);
      a.click();
    };
    img.onerror = () => URL.revokeObjectURL(objectUrl);
    img.src = objectUrl;
  }

  countCondition(condition: ConditionDentaire): number {
    return this.dentsEtat.filter(e => e.condition === condition).length;
  }

  fermer(): void {
    this.fermerEvent.emit();
  }
}
