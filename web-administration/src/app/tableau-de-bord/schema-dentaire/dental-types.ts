export type ConditionDentaire =
  | 'sain' | 'carie' | 'extraction' | 'couronne' | 'canal'
  | 'bridge' | 'implant' | 'fracture' | 'detartrage' | 'obturation';

export interface EtatDent {
  numero: number;
  condition: ConditionDentaire;
  notes: string;
}

export interface ActePlanifie {
  id: string;
  dent: number;
  type: ConditionDentaire;
  libelle: string;
  statut: 'planifie' | 'en_cours' | 'termine';
}
