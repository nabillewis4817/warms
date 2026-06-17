import { Component, EventEmitter, OnInit, Output, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { SchemasDentairesService, SchemaSauvegarde } from '../../noyau/services/schemas-dentaires.service';

@Component({
  selector: 'app-schemas-liste',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './schemas-liste.html',
  styleUrl: './schemas-liste.scss',
})
export class SchemasListe implements OnInit {
  @Output() fermerEvent  = new EventEmitter<void>();
  @Output() modifierEvent = new EventEmitter<SchemaSauvegarde>();

  private readonly schemasSvc = inject(SchemasDentairesService);

  schemas: SchemaSauvegarde[]      = [];
  recherche                         = '';
  schemaVu: SchemaSauvegarde | null = null;
  schemaASupprimer: SchemaSauvegarde | null = null;
  exportFormatVu: 'png' | 'jpg' | null = null;

  get schemasFiltres(): SchemaSauvegarde[] {
    const q = this.recherche.toLowerCase().trim();
    if (!q) return this.schemas;
    return this.schemas.filter(s =>
      `${s.patient.prenom} ${s.patient.nom}`.toLowerCase().includes(q) ||
      (s.patient.numero_dossier ?? '').toLowerCase().includes(q)
    );
  }

  ngOnInit(): void {
    this.charger();
  }

  charger(): void {
    this.schemas = this.schemasSvc.lister().sort(
      (a, b) => new Date(b.dateMaj).getTime() - new Date(a.dateMaj).getTime()
    );
  }

  initiales(s: SchemaSauvegarde): string {
    return ((s.patient.prenom ?? '').charAt(0) + (s.patient.nom ?? '').charAt(0)).toUpperCase();
  }

  formatDate(iso: string): string {
    return new Date(iso).toLocaleDateString('fr-FR', {
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  }

  voirImage(schema: SchemaSauvegarde): void {
    this.schemaVu = schema;
  }

  fermerVue(): void {
    this.schemaVu = null;
    this.exportFormatVu = null;
  }

  modifier(schema: SchemaSauvegarde): void {
    this.modifierEvent.emit(schema);
  }

  demanderSuppression(schema: SchemaSauvegarde): void {
    this.schemaASupprimer = schema;
  }

  confirmerSuppression(): void {
    if (!this.schemaASupprimer) return;
    this.schemasSvc.supprimer(this.schemaASupprimer.id);
    if (this.schemaVu?.id === this.schemaASupprimer.id) this.schemaVu = null;
    this.schemaASupprimer = null;
    this.charger();
  }

  exporter(schema: SchemaSauvegarde, format: 'png' | 'jpg' = 'png'): void {
    if (!schema.apercu) return;
    const a = document.createElement('a');
    if (format === 'png') {
      a.href = schema.apercu;
      a.download = `schema_${schema.patient.nom}_${schema.dateCreation.split('T')[0]}.png`;
      a.click();
      return;
    }
    // Convertir PNG → JPG via canvas
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = img.naturalWidth;
      canvas.height = img.naturalHeight;
      const ctx = canvas.getContext('2d')!;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0);
      a.href = canvas.toDataURL('image/jpeg', 0.92);
      a.download = `schema_${schema.patient.nom}_${schema.dateCreation.split('T')[0]}.jpg`;
      a.click();
    };
    img.src = schema.apercu;
  }

  fermer(): void {
    this.fermerEvent.emit();
  }
}
