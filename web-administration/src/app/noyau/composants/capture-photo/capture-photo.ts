import { Component, ElementRef, EventEmitter, Input, OnDestroy, Output, ViewChild } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-capture-photo',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './capture-photo.html',
  styleUrl: './capture-photo.scss',
})
export class CapturePhoto implements OnDestroy {
  @Input() photoUrl: string | null = null;
  @Input() initiales = '';
  @Input() taille: 'normal' | 'grande' = 'normal';
  @Output() fichierChange = new EventEmitter<File | null>();

  @ViewChild('inputFichier') inputFichier!: ElementRef<HTMLInputElement>;
  @ViewChild('video') videoEl?: ElementRef<HTMLVideoElement>;

  previewLocal: string | null = null;
  cameraOuverte = false;
  cameraErreur = '';
  private stream: MediaStream | null = null;

  get apercu(): string | null {
    return this.previewLocal ?? this.photoUrl;
  }

  declencherFichier(): void {
    this.inputFichier.nativeElement.click();
  }

  onFichierSelectionne(event: Event): void {
    const input = event.target as HTMLInputElement;
    const fichier = input.files?.[0];
    if (!fichier) return;
    this.appliquerFichier(fichier);
    input.value = '';
  }

  async ouvrirCamera(): Promise<void> {
    this.cameraErreur = '';
    this.cameraOuverte = true;
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: false });
      setTimeout(() => {
        if (this.videoEl) {
          this.videoEl.nativeElement.srcObject = this.stream;
        }
      });
    } catch {
      this.cameraErreur = "Impossible d'accéder à la caméra. Vérifiez les autorisations du navigateur.";
    }
  }

  capturer(): void {
    if (!this.videoEl) return;
    const video = this.videoEl.nativeElement;
    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth || 480;
    canvas.height = video.videoHeight || 480;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    canvas.toBlob((blob) => {
      if (!blob) return;
      const fichier = new File([blob], `photo_${Date.now()}.jpg`, { type: 'image/jpeg' });
      this.appliquerFichier(fichier);
      this.fermerCamera();
    }, 'image/jpeg', 0.9);
  }

  fermerCamera(): void {
    this.cameraOuverte = false;
    this.stream?.getTracks().forEach((t) => t.stop());
    this.stream = null;
  }

  supprimerPhoto(): void {
    this.previewLocal = null;
    this.photoUrl = null;
    this.fichierChange.emit(null);
  }

  private appliquerFichier(fichier: File): void {
    const reader = new FileReader();
    reader.onload = () => { this.previewLocal = reader.result as string; };
    reader.readAsDataURL(fichier);
    this.fichierChange.emit(fichier);
  }

  ngOnDestroy(): void {
    this.fermerCamera();
  }
}
