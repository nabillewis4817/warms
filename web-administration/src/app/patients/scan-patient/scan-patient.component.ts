import { Component, ElementRef, OnDestroy, OnInit, ViewChild, inject } from '@angular/core';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';

interface VerifQRResponse {
  dossier: { id: string; numero_dossier: string };
  patient: { id: number; prenom: string; nom: string };
}

@Component({
  selector: 'app-scan-patient',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './scan-patient.component.html',
})
export class ScanPatientComponent implements OnInit, OnDestroy {
  @ViewChild('videoEl', { static: true }) videoEl!: ElementRef<HTMLVideoElement>;

  private router = inject(Router);
  private http = inject(HttpClient);

  etat: 'init' | 'scan' | 'trouve' | 'erreur' = 'init';
  patient?: VerifQRResponse['patient'];
  dossierId?: string;
  messageErreur = '';
  private stream?: MediaStream;
  private barcodeDetector?: any; // eslint-disable-line @typescript-eslint/no-explicit-any
  private intervalId?: ReturnType<typeof setInterval>;

  async ngOnInit(): Promise<void> {
    if (!('BarcodeDetector' in window)) {
      this.etat = 'erreur';
      this.messageErreur = 'Votre navigateur ne supporte pas le scanner QR (utilisez Chrome ou Edge récent).';
      return;
    }
    this.barcodeDetector = new (window as any)['BarcodeDetector']({ formats: ['qr_code'] }); // eslint-disable-line
    await this.demarrerCamera();
  }

  async demarrerCamera(): Promise<void> {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment', width: 640, height: 480 }
      });
      this.videoEl.nativeElement.srcObject = this.stream;
      await this.videoEl.nativeElement.play();
      this.etat = 'scan';
      this.intervalId = setInterval(() => void this.scannerFrame(), 400);
    } catch {
      this.etat = 'erreur';
      this.messageErreur = 'Impossible d\'accéder à la caméra. Vérifiez les permissions du navigateur.';
    }
  }

  private async scannerFrame(): Promise<void> {
    const video = this.videoEl.nativeElement;
    if (video.readyState < video.HAVE_ENOUGH_DATA) return;
    try {
      const codes = await this.barcodeDetector.detect(video);
      if (codes.length > 0) {
        this.arreterCamera();
        await this.verifierToken(codes[0].rawValue as string);
      }
    } catch { /* ignore */ }
  }

  private verifierToken(token: string): void {
    this.etat = 'init';
    this.http.post<VerifQRResponse>('/api/v1/qr/carnets/verifier/', { token }).subscribe({
      next: (res) => {
        this.patient = res.patient;
        this.dossierId = res.dossier.id;
        this.etat = 'trouve';
      },
      error: () => {
        this.etat = 'erreur';
        this.messageErreur = 'QR invalide ou expiré. Demandez au patient de régénérer son QR code.';
      }
    });
  }

  ouvrirDossier(): void {
    if (this.patient) {
      void this.router.navigate(['/patients', this.patient.id, 'dossier']);
    }
  }

  recommencer(): void {
    this.patient = undefined;
    this.dossierId = undefined;
    this.messageErreur = '';
    void this.demarrerCamera();
  }

  private arreterCamera(): void {
    clearInterval(this.intervalId);
    this.stream?.getTracks().forEach(t => t.stop());
  }

  ngOnDestroy(): void {
    this.arreterCamera();
  }
}
