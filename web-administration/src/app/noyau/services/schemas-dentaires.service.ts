import { Injectable } from '@angular/core';
import { Patient } from './patients';
import { EtatDent, ActePlanifie } from '../../tableau-de-bord/schema-dentaire/dental-types';

export interface SchemaSauvegarde {
  id: string;
  patient: Patient;
  dateCreation: string;
  dateMaj: string;
  dentsEtat: EtatDent[];
  actesPlanifies: ActePlanifie[];
  apercu: string;
  traitements: number;
}

@Injectable({ providedIn: 'root' })
export class SchemasDentairesService {
  private readonly CLE = 'warms_schemas_dentaires';

  lister(): SchemaSauvegarde[] {
    try {
      return JSON.parse(localStorage.getItem(this.CLE) ?? '[]');
    } catch {
      return [];
    }
  }

  obtenir(id: string): SchemaSauvegarde | null {
    return this.lister().find(s => s.id === id) ?? null;
  }

  sauvegarder(
    data: Omit<SchemaSauvegarde, 'id' | 'dateCreation' | 'dateMaj'> & { id?: string; dateCreation?: string }
  ): SchemaSauvegarde {
    const tous = this.lister();
    const now = new Date().toISOString();
    const existant = data.id ? tous.find(s => s.id === data.id) : undefined;
    const schema: SchemaSauvegarde = {
      ...data,
      id: data.id ?? this.genId(),
      dateCreation: existant?.dateCreation ?? now,
      dateMaj: now,
    };
    if (existant) {
      const idx = tous.findIndex(s => s.id === schema.id);
      tous[idx] = schema;
    } else {
      tous.unshift(schema);
    }
    localStorage.setItem(this.CLE, JSON.stringify(tous));
    return schema;
  }

  supprimer(id: string): void {
    localStorage.setItem(
      this.CLE,
      JSON.stringify(this.lister().filter(s => s.id !== id))
    );
  }

  private genId(): string {
    return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
  }
}
