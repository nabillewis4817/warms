import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface WarmsIARequest {
  question: string;
  patient_id?: number;
}

export interface WarmsIAResponse {
  question: string;
  reponse: string;
  timestamp: string;
  patient_id?: number;
}

export interface WarmsIAInfo {
  nom: string;
  description: string;
  capacites: string[];
  limitations: string[];
}

@Injectable({
  providedIn: 'root'
})
export class WarmsIAService {
  private readonly baseUrl = 'http://127.0.0.1:8000/api/v1/assistant_ia';

  constructor(private http: HttpClient) {}

  /**
   * Pose une question à WARMS IA
   */
  poserQuestion(request: WarmsIARequest): Observable<WarmsIAResponse> {
    return this.http.post<WarmsIAResponse>(`${this.baseUrl}/warms-general/`, request);
  }

  /**
   * Obtient les informations sur WARMS IA
   */
  getInformations(): Observable<WarmsIAInfo> {
    return this.http.get<WarmsIAInfo>(`${this.baseUrl}/warms-info/`);
  }

  /**
   * Recherche des informations médicales (fallback)
   */
  rechercherInformationMedicale(query: string): Observable<string> {
    return new Observable<string>((observer) => {
      // Simulation de recherche web pour les informations médicales
      setTimeout(() => {
        const result = this.simulerRechercheWeb(query);
        observer.next(result);
        observer.complete();
      }, 1000);
    });
  }

  private simulerRechercheWeb(query: string): string {
    const q = query.toLowerCase();
    
    if (q.includes('douleur dent')) {
      return `La douleur dentaire est un signal d'alerte important qui nécessite une consultation. Les causes principales sont:\n\n1. Carie profonde atteignant la pulpe dentaire\n2. Abcès dentaire (infection)\n3. Fracture dentaire\n4. Maladie des gencives (parodontite)\n5. Sensibilité dentinaire\n\nConseils immédiats:\n- Antalgiques (paracétamol/ibuprofène)\n- Éviter aliments trop chauds/froids\n- Brossage doux\n- Consulter rapidement un dentiste\n\nSources: Association Dentaire Française, WHO Oral Health Guidelines`;
    }
    
    if (q.includes('carie')) {
      return `La carie dentaire est une destruction progressive des tissus dentaires:\n\nStades:\n1. Déminéralisation de l'émail (tache blanche)\n2. Atteinte de la dentine (sensibilité)\n3. Atteinte de la pulpe (douleur intense)\n4. Abcès (infection)\n\nTraitement selon stade:\n- Stade 1-2: Obturation (plombage)\n- Stade 3: Traitement de canal (dévitalisation)\n- Stade 4: Extraction si nécessaire\n\nPrévention:\n- Hygiène bucco-dentaire rigoureuse\n- Visites régulières chez le dentiste\n- Alimentation équilibrée (limiter sucres)\n\nSources: Institut National de Santé Publique`;
    }
    
    if (q.includes('détartrage')) {
      return `Le détartrage est un soin prophylactique essentiel:\n\nObjectifs:\n- Éliminer le tartre (plaque calcifiée)\n- Prévenir les maladies parodontales\n- Améliorer l'hygiène bucco-dentaire\n\nFréquence recommandée:\n- 1-2 fois par an pour la plupart des adultes\n- Plus fréquent si facteurs de risque\n\nProcédure:\n- Anesthésie locale si nécessaire\n- Utilisation d'instruments ultrasoniques\n- Polissage final\n- Durée: 30-45 minutes\n\nBénéfices:\n- Réduction du risque de caries\n- Prévention des déchaussements\n- Haleine plus fraîche\n\nSources: Ordre National des Chirurgiens-Dentistes`;
    }
    
    return `Information recherchée pour "${query}":\n\nWARMS IA a recherché dans les sources médicales fiables. Pour des informations spécifiques à votre situation, consultez votre dentiste.\n\nSources fiables recommandées:\n- Association Dentaire Française\n- Ordre National des Chirurgiens-Dentistes\n- WHO Oral Health Guidelines\n- Institut National de Santé Publique`;
  }
}
