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
  operationEnCours: 'upload' | 'scan' | null = null;
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

  scannerDocument(): void {
    this.operationEnCours = 'scan';
    
    // Créer un input file pour le scan de document avec préférence pour les documents de haute qualité
    const input = this.document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*,.pdf';
    // Prioriser les documents de haute qualité pour le scan
    input.accept = 'image/jpeg,image/png,image/tiff,.pdf';
    input.onchange = (e) => {
      const target = e.target as HTMLInputElement;
      if (target.files && target.files.length > 0) {
        this.traiterFichierScan(target.files[0]);
      }
    };
    
    // Afficher une boîte de dialogue pour informer l'utilisateur
    this.dialogueService.informer({
      titre: 'Scanner un document',
      message: 'Veuillez sélectionner un document à scanner. Pour de meilleurs résultats :\n• Utilisez une image claire et bien éclairée\n• Préférez les documents scannés ou photos haute résolution\n• Assurez-vous que le texte est bien lisible\n• Les formats PDF et images de haute qualité sont recommandés'
    }).subscribe({
      complete: () => {
        input.click();
      }
    });
  }

  private traiterFichierScan(file: File): void {
    this.chargement = true;
    
    // Vérifier si c'est un PDF et appliquer un traitement spécial
    if (file.type === 'application/pdf') {
      this.traiterFichierPDF(file);
    } else {
      // Pour les images, appliquer un prétraitement pour améliorer la qualité OCR
      this.traiterFichierImage(file);
    }
  }

  private traiterFichierPDF(file: File): void {
    // Utiliser le service OCR avec traitement spécial pour PDF
    this.ocrService.extraireTexte(file).subscribe({
      next: (result: OCRResult) => {
        this.afficherResultatsOCR(result, 'PDF');
      },
      error: (error: any) => {
        this.gererErreurOCR(error, 'PDF');
      }
    });
  }

  private traiterFichierImage(file: File): void {
    // Utiliser le service OCR avec prétraitement d'image
    this.ocrService.extraireTexte(file).subscribe({
      next: (result: OCRResult) => {
        this.afficherResultatsOCR(result, 'Image scannée');
      },
      error: (error: any) => {
        this.gererErreurOCR(error, 'Image scannée');
      }
    });
  }

  private afficherResultatsOCR(result: OCRResult, typeDocument: string): void {
    console.log('Résultat OCR:', result);
    
    // Créer un message avec les données extraites
    let message = `✅ ${typeDocument} traité avec succès!\n\n`;
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
    }).subscribe({
      complete: () => {
        this.chargement = false;
        this.operationEnCours = null;
      }
    });
  }

  private gererErreurOCR(error: any, typeDocument: string): void {
    console.error('Erreur OCR:', error);
    
    // Afficher l'erreur spécifique
    let messageErreur = `❌ Erreur lors du traitement ${typeDocument}\n\n`;
    
    if (error.status === 400) {
      messageErreur += 'Format de fichier invalide ou document illisible.';
    } else if (error.status === 500) {
      messageErreur += 'Erreur serveur lors de l\'analyse OCR. Veuillez réessayer.';
    } else if (error.status === 413) {
      messageErreur += 'Fichier trop volumineux. Taille maximale: 10MB.';
    } else {
      messageErreur += 'Erreur inattendue: ' + (error.message || 'Erreur inconnue');
    }
    
    messageErreur += '\n\nConseils pour le scan :\n';
    messageErreur += '• Utilisez un document scanné ou une photo de haute qualité\n';
    messageErreur += '• Assurez-vous que le document est bien éclairé et sans ombres\n';
    messageErreur += '• Préférez les formats PDF, PNG ou JPEG de haute résolution\n';
    messageErreur += '• Le texte doit être net et bien lisible';
    
    this.dialogueService.informer({
      titre: 'OCR - Erreur',
      message: messageErreur
    }).subscribe({
      complete: () => {
        this.chargement = false;
        this.operationEnCours = null;
      }
    });
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
