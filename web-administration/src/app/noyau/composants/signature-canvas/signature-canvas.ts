import {
  AfterViewInit,
  Component,
  ElementRef,
  EventEmitter,
  Output,
  ViewChild,
} from '@angular/core';

@Component({
  selector: 'app-signature-canvas',
  standalone: true,
  template: `
    <div class="sc-conteneur">
      <canvas
        #cnv
        class="sc-canvas"
        (mousedown)="debutSouris($event)"
        (mousemove)="tracerSouris($event)"
        (mouseup)="terminer()"
        (mouseleave)="terminer()"
        (touchstart)="debutTouch($event)"
        (touchmove)="tracerTouch($event)"
        (touchend)="terminer()"
      ></canvas>
      <div class="sc-barre">
        <span class="sc-indice" [style.opacity]="vide ? '1' : '0'">
          Signez ici avec votre souris ou votre doigt
        </span>
        <button type="button" class="sc-effacer" [disabled]="vide" (click)="effacer()">
          <i class="bi bi-eraser-fill"></i> Effacer
        </button>
      </div>
    </div>
  `,
  styles: [`
    .sc-conteneur {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .sc-canvas {
      width: 100%;
      height: 180px;
      border: 2px dashed #cbd5e1;
      border-radius: 10px;
      background: #fff;
      cursor: crosshair;
      touch-action: none;
      display: block;
      transition: border-color 0.15s ease;
    }
    .sc-canvas:hover {
      border-color: #1e4db7;
    }
    .sc-barre {
      display: flex;
      align-items: center;
      justify-content: space-between;
      min-height: 26px;
    }
    .sc-indice {
      font-size: 12px;
      color: #94a3b8;
      transition: opacity 0.2s ease;
    }
    .sc-effacer {
      padding: 4px 12px;
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      background: #f8fafc;
      font-size: 12px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 5px;
      transition: background 0.15s ease, border-color 0.15s ease, color 0.15s ease;
    }
    .sc-effacer:disabled {
      opacity: 0.4;
      cursor: not-allowed;
    }
    .sc-effacer:not(:disabled):hover {
      background: #fee2e2;
      border-color: #fca5a5;
      color: #dc2626;
    }
  `],
})
export class SignatureCanvas implements AfterViewInit {
  @ViewChild('cnv') canvasRef!: ElementRef<HTMLCanvasElement>;

  /** Émet true quand le canvas contient un tracé, false après effacement. */
  @Output() modifiee = new EventEmitter<boolean>();

  vide = true;
  private dessine = false;
  private ctx!: CanvasRenderingContext2D;

  ngAfterViewInit(): void {
    const el = this.canvasRef.nativeElement;
    el.width  = el.offsetWidth  || 560;
    el.height = el.offsetHeight || 180;
    const ctx = el.getContext('2d')!;
    ctx.lineWidth   = 2.5;
    ctx.lineCap     = 'round';
    ctx.lineJoin    = 'round';
    ctx.strokeStyle = '#1e3a6e';
    this.ctx = ctx;
  }

  private coordonnees(e: MouseEvent | Touch): { x: number; y: number } {
    const rect   = this.canvasRef.nativeElement.getBoundingClientRect();
    const scaleX = this.canvasRef.nativeElement.width  / rect.width;
    const scaleY = this.canvasRef.nativeElement.height / rect.height;
    return {
      x: (e.clientX - rect.left) * scaleX,
      y: (e.clientY - rect.top)  * scaleY,
    };
  }

  debutSouris(e: MouseEvent): void {
    this.dessine = true;
    const p = this.coordonnees(e);
    this.ctx.beginPath();
    this.ctx.moveTo(p.x, p.y);
  }

  tracerSouris(e: MouseEvent): void {
    if (!this.dessine) return;
    const p = this.coordonnees(e);
    this.ctx.lineTo(p.x, p.y);
    this.ctx.stroke();
    if (this.vide) { this.vide = false; this.modifiee.emit(true); }
  }

  debutTouch(e: TouchEvent): void {
    e.preventDefault();
    this.dessine = true;
    const p = this.coordonnees(e.touches[0]);
    this.ctx.beginPath();
    this.ctx.moveTo(p.x, p.y);
  }

  tracerTouch(e: TouchEvent): void {
    e.preventDefault();
    if (!this.dessine) return;
    const p = this.coordonnees(e.touches[0]);
    this.ctx.lineTo(p.x, p.y);
    this.ctx.stroke();
    if (this.vide) { this.vide = false; this.modifiee.emit(true); }
  }

  terminer(): void {
    this.dessine = false;
  }

  effacer(): void {
    const el = this.canvasRef.nativeElement;
    this.ctx.clearRect(0, 0, el.width, el.height);
    this.vide = true;
    this.modifiee.emit(false);
  }

  /** Renvoie la signature en base64 PNG, ou null si le canvas est vide. */
  exporter(): string | null {
    return this.vide ? null : this.canvasRef.nativeElement.toDataURL('image/png');
  }
}

// #EbaJioloLewis
