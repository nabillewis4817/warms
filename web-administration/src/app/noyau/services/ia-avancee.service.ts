import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

export interface RechercheWebResult {
  titre: string;
  url: string;
  snippet: string;
  source: string;
  date?: string;
  pertinence: number;
}

export interface ReponseIA {
  question: string;
  reponse: string;
  sources: RechercheWebResult[];
  confiance: number;
  temps_generation: number;
  contexte?: string;
}

export interface ContexteMedical {
  patient_id?: number;
  symptomes?: string[];
  diagnostic?: string;
  traitements?: string[];
  antecedents?: string[];
}

@Injectable({
  providedIn: 'root'
})
export class IAAvanceeService {
  private readonly apiUrl = `${environment.apiBaseUrl}/ia-avancee`;
  private apiKey = 'YOUR_API_KEY'; // À configurer

  constructor(private http: HttpClient) {}

  // Recherche web avancée
  rechercheWeb(query: string, limit: number = 10): Observable<RechercheWebResult[]> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<{ results: RechercheWebResult[] }>(`${this.apiUrl}/recherche-web/`, 
      { query, limit }, 
      { headers }
    ).pipe(map(response => response.results));
  }

  // Recherche médicale spécialisée
  rechercheMedicale(query: string, contexte?: ContexteMedical): Observable<RechercheWebResult[]> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<{ results: RechercheWebResult[] }>(`${this.apiUrl}/recherche-medicale/`, 
      { query, contexte }, 
      { headers }
    ).pipe(map(response => response.results));
  }

  // Génération de réponse IA avec sources
  genererReponse(question: string, contexte?: ContexteMedical): Observable<ReponseIA> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<ReponseIA>(`${this.apiUrl}/generer-reponse/`, 
      { question, contexte }, 
      { headers }
    );
  }

  // Analyse de symptômes
  analyserSymptomes(symptomes: string[], patient_info?: any): Observable<{
    diagnostic_possibles: Array<{
      condition: string;
      probabilite: number;
      symptomes_associes: string[];
      recommandations: string[];
    }>;
    urgence: boolean;
    confiance: number;
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/analyser-symptomes/`, 
      { symptomes, patient_info }, 
      { headers }
    );
  }

  // Suggestion de traitements
  suggererTraitements(diagnostic: string, patient_info?: any): Observable<{
    traitements: Array<{
      nom: string;
      type: string;
      description: string;
      posologie?: string;
      contre_indications?: string[];
      efficacite: number;
    }>;
    alternatives: Array<{
      nom: string;
      description: string;
      avantages: string[];
    }>;
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/suggerer-traitements/`, 
      { diagnostic, patient_info }, 
      { headers }
    );
  }

  // Interprétation d'analyses médicales
  interpreterAnalyses(resultats_analyses: any, patient_info?: any): Observable<{
    interpretation: string;
    valeurs_anormales: Array<{
      parametre: string;
      valeur: string;
      normale: string;
      interpretation: string;
    }>;
    recommandations: string[];
    suivi: string;
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/interpreter-analyses/`, 
      { resultats_analyses, patient_info }, 
      { headers }
    );
  }

  // Vérification des interactions médicamenteuses
  verifierInteractions(medicaments: string[]): Observable<{
    interactions: Array<{
      medicament1: string;
      medicament2: string;
      niveau: 'faible' | 'moderee' | 'severe' | 'critique';
      description: string;
      recommandations: string[];
    }>;
    alternatives_suggeres: Array<{
      medicament_original: string;
      alternatives: string[];
    }>;
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/verifier-interactions/`, 
      { medicaments }, 
      { headers }
    );
  }

  // Génération de rapport médical
  genererRapport(patient_info: any, consultations: any[]): Observable<{
    resume: string;
    diagnostic_principal: string;
    evolution: string;
    recommandations: string[];
    prochain_rdv: string;
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/generer-rapport/`, 
      { patient_info, consultations }, 
      { headers }
    );
  }

  // Recherche d'informations sur les médicaments
  rechercherMedicament(nom_medicament: string): Observable<{
    nom: string;
    description: string;
    classe_therapeutique: string;
    indications: string[];
    contre_indications: string[];
    effets_secondaires: string[];
    posologie: string;
    precautions: string[];
    sources: RechercheWebResult[];
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/rechercher-medicament/`, 
      { nom_medicament }, 
      { headers }
    );
  }

  // Traduction médicale
  traduireTermeMedical(terme: string, langue_source: string, langue_cible: string): Observable<{
    terme_original: string;
    terme_traduit: string;
    definition: string;
    contexte: string;
    alternatives: string[];
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/traduire-terme/`, 
      { terme, langue_source, langue_cible }, 
      { headers }
    );
  }

  // Vérification de la fiabilité des sources
  verifierFiabiliteSources(urls: string[]): Observable<Array<{
    url: string;
    fiabilite: number;
    type: 'scientifique' | 'medical' | 'gouvernemental' | 'commercial' | 'inconnu';
    recommandations: string[];
  }>> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/verifier-fiabilite/`, 
      { urls }, 
      { headers }
    );
  }

  // Mise à jour des connaissances médicales
  mettreAJourConnaissances(specialite: string): Observable<{
    nouvelles_donnees: Array<{
      titre: string;
      source: string;
      date: string;
      resume: string;
      impact: 'faible' | 'modere' | 'eleve';
    }>;
    date_mise_a_jour: string;
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/mettre-a-jour/`, 
      { specialite }, 
      { headers }
    );
  }

  // Chatbot médical conversationnel
  chatMedical(message: string, conversation_id?: string, contexte?: ContexteMedical): Observable<{
    reponse: string;
    conversation_id: string;
    suggestions: string[];
    questions_suivantes: string[];
    niveau_urgence: 'aucun' | 'faible' | 'modere' | 'eleve';
    consulter_medecin: boolean;
  }> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/chat-medical/`, 
      { message, conversation_id, contexte }, 
      { headers }
    );
  }

  // Configuration du service IA
  configurerService(config: {
    api_key?: string;
    modele?: string;
    temperature?: number;
    max_tokens?: number;
  }): Observable<{ success: boolean; message: string }> {
    if (config.api_key) {
      this.apiKey = config.api_key;
    }

    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'X-API-Key': this.apiKey
    });

    return this.http.post<any>(`${this.apiUrl}/configurer/`, config, { headers });
  }
}
