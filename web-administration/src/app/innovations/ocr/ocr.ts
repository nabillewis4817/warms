import { CommonModule } from '@angular/common';
import { Component, ViewChild, ElementRef, Inject, OnInit } from '@angular/core';
import { DOCUMENT } from '@angular/common';
import { OcrService, OCRResult } from '../../noyau/services/ocr';
import { DialogueService } from '../../noyau/services/dialogue.service';

@Component({
  selector: 'app-ocr',
  imports: [CommonModule],
  templateUrl: './ocr.html',
  styleUrl: './ocr.scss',
})
export class Ocr {
  chargement = false;
  operationEnCours: 'upload' | 'photo' | null = null;
  @ViewChild('fileInput') fileInput!: ElementRef<HTMLInputElement>;
  
  constructor(
    @Inject(DOCUMENT) private document: Document,
    private ocrService: OcrService,
    private dialogueService: DialogueService
  ) {}

  onFileUpload(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.traiterFichier(input.files[0]);
    }
  }

  clickFileInput(): void {
    if (this.fileInput) {
      this.fileInput.nativeElement.click();
    }
  }

  prendrePhoto(): void {
    this.operationEnCours = 'photo';
    // Créer un input file pour capturer depuis la caméra
    const input = this.document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.capture = 'environment';
    input.onchange = (e) => {
      const target = e.target as HTMLInputElement;
      if (target.files && target.files.length > 0) {
        this.traiterFichier(target.files[0]);
      }
    };
    input.click();
  }

  private traiterFichier(file: File): void {
    this.chargement = true;
    
    // Utiliser le service OCR avec pytesseract
    this.ocrService.extraireTexte(file).subscribe({
      next: (result: OCRResult) => {
        console.log('Résultat OCR:', result);
        
        // Créer un message avec les données extraites
        let message = '✅ OCR traité avec succès!\n\n';
        message += 'Texte extrait :\n';
        message += result.texte_extrait || 'Aucun texte extrait';
        
        if (result.donnees_structurees) {
          const { nom, prenom, date_naissance, telephone, email, adresse } = result.donnees_structurees;
          message += '\n\nDonnées structurées extraites :\n';
          if (prenom) message += `• Prénom: ${prenom}\n`;
          if (nom) message += `• Nom: ${nom}\n`;
          if (date_naissance) message += `• Date de naissance: ${date_naissance}\n`;
          if (telephone) message += `• Téléphone: ${telephone}\n`;
          if (email) message += `• Email: ${email}\n`;
          if (adresse) message += `• Adresse: ${adresse}\n`;
        }
        
        if (result.symotomes && result.symotomes.length > 0) {
          message += '\n\nSymptômes détectés :\n';
          result.symotomes.forEach((symptome: string, index: number) => {
            message += `${index + 1}. ${symptome}\n`;
          });
        }
        
        if (result.traitements && result.traitements.length > 0) {
          message += '\n\nTraitements détectés :\n';
          result.traitements.forEach((traitement: string, index: number) => {
            message += `${index + 1}. ${traitement}\n`;
          });
        }
        
        message += `\n\nConfiance: ${(result.confiance || 0.85) * 100}%`;
        
        this.dialogueService.informer({
          titre: 'OCR - Extraction réussie',
          message: message
        }).subscribe();
      },
      error: (error) => {
        console.error('Erreur OCR:', error);
        
        // Afficher l'erreur spécifique
        let messageErreur = '❌ Erreur lors du traitement OCR\n\n';
        
        if (error.status === 400) {
          messageErreur += 'Format de fichier invalide ou image illisible.';
        } else if (error.status === 500) {
          messageErreur += 'Erreur serveur lors de l\'analyse OCR. Veuillez réessayer.';
        } else if (error.status === 413) {
          messageErreur += 'Fichier trop volumineux. Taille maximale: 10MB.';
        } else {
          messageErreur += 'Erreur inattendue: ' + (error.message || 'Erreur inconnue');
        }
        
        messageErreur += '\n\nConseils :\n';
        messageErreur += '• Utilisez une image claire et bien éclairée\n';
        messageErreur += '• Préférez les formats PNG ou JPEG\n';
        messageErreur += '• Assurez-vous que le texte est lisible';
        
        this.dialogueService.informer({
          titre: 'OCR - Erreur',
          message: messageErreur
        }).subscribe({
          next: () => {},
          error: () => {},
          complete: () => {
            this.chargement = false;
            this.operationEnCours = null;
          }
        });
      }
    });
  }
}

// #EbaJioloLewis
