import { CommonModule } from '@angular/common';
import { Component, ViewChild, ElementRef, Inject } from '@angular/core';
import { DOCUMENT } from '@angular/common';
import { OcrService, OCRResult } from '../../noyau/services/ocr';

@Component({
  selector: 'app-ocr',
  imports: [CommonModule],
  templateUrl: './ocr.html',
  styleUrl: './ocr.scss',
})
export class Ocr {
  chargement = false;
  operationEnCours: 'upload' | 'scan' | null = null;
  resultat: OCRResult | null = null;
  nomFichierTraite = '';
  erreur: { titre: string; message: string } | null = null;

  @ViewChild('fileInput') fileInput!: ElementRef<HTMLInputElement>;

  constructor(
    @Inject(DOCUMENT) private document: Document,
    private ocrService: OcrService
  ) {}

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
        message:
          error.error?.detail ||
          "Le moteur Tesseract OCR n'est pas installé ou accessible sur le serveur. Contactez votre administrateur système.",
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
      message: error.error?.detail || "Une erreur inattendue est survenue lors du traitement OCR.",
    };
  }

  fermerResultat(): void {
    this.resultat = null;
    this.nomFichierTraite = '';
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
    const champs: { label: string; valeur: string }[] = [];
    if (d.prenom) champs.push({ label: 'Prénom', valeur: d.prenom });
    if (d.nom) champs.push({ label: 'Nom', valeur: d.nom });
    if (d.date_naissance) champs.push({ label: 'Date de naissance', valeur: d.date_naissance });
    if (d.telephone) champs.push({ label: 'Téléphone', valeur: d.telephone });
    if (d.email) champs.push({ label: 'Email', valeur: d.email });
    if (d.adresse) champs.push({ label: 'Adresse', valeur: d.adresse });
    return champs;
  }
}

// #EbaJioloLewis
