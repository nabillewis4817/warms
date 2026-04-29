// ========================================
// COMPOSANT POUR L'ONGLET CARNETS DES PATIENTS
// ========================================
// Affiche la liste des carnets patients avec leurs informations
// Auto-rafraîchissement toutes les 30 secondes
// Gestion des erreurs de chargement d'images

import { CommonModule } from '@angular/common';
import { Component, OnInit, inject, OnDestroy } from '@angular/core';
import { interval, Subscription } from 'rxjs';
import { Router } from '@angular/router';
import { FormsModule } from '@angular/forms';

import { Patient, Patients } from '../../noyau/services/patients';

@Component({
  selector: 'app-carnets',
  imports: [CommonModule, FormsModule],
  templateUrl: './carnets.html',
  styleUrl: './carnets.scss',
})
export class Carnets implements OnInit, OnDestroy {
  // ========================================
  // INJECTIONS DE DÉPENDANCES
  // ========================================
  private readonly servicePatients = inject(Patients);
  private readonly router = inject(Router);

  // ========================================
  // PROPRIÉTÉS DU COMPOSANT
  // ========================================
  /** Liste des patients avec carnets */
  patients: Patient[] = [];
  
  /** Liste filtrée des patients pour la recherche */
  patientsFiltres: Patient[] = [];
  
  /** Indicateur de chargement pour l'interface */
  enChargement: boolean = false;
  
  /** Abonnement pour l'auto-rafraîchissement */
  private abonnementRafraichissement: Subscription | null = null;
  
  /** Chemin vers l'image du dossier */
  private readonly cheminImageDossier: string = 'assets/folder.png';
  
  /** Terme de recherche */
  termeRecherche: string = '';
  
  /** Critère de tri actuel */
  critereTri: string = 'nom';
  
  /** Ordre de tri (ascendant/descendant) */
  ordreTri: 'asc' | 'desc' = 'asc';

  // ========================================
  // MÉTHODES DU CYCLE DE VIE
  // ========================================
  
  /**
   * Initialisation du composant
   * Démarre le chargement initial et l'auto-rafraîchissement
   */
  ngOnInit(): void {
    console.log('🚀 Initialisation du composant Carnets Patients');
    this.chargerLesCarnets();
    this.demarrerAutoRafraichissement();
  }

  /**
   * Nettoyage lors de la destruction du composant
   * Annule l'abonnement d'auto-rafraîchissement
   */
  ngOnDestroy(): void {
    console.log('🧹 Nettoyage du composant Carnets Patients');
    this.arreterAutoRafraichissement();
  }

  // ========================================
  // MÉTHODES PUBLIQUES
  // ========================================

  /**
   * Charge la liste des patients depuis le service
   * Filtre uniquement les patients ayant un numéro de dossier
   */
  chargerLesCarnets(): void {
    console.log('📂 Chargement des carnets patients...');
    this.enChargement = true;

    this.servicePatients.lister().subscribe({
      next: (patientsRecus) => {
        // Filtrer uniquement les patients avec un numéro de dossier
        this.patients = patientsRecus.filter((patient) => !!patient.numero_dossier);
        this.appliquerFiltreEtTri();
        this.enChargement = false;
        console.log(`✅ ${this.patients.length} carnets patients chargés`);
      },
      error: (erreur) => {
        console.error('❌ Erreur lors du chargement des carnets:', erreur);
        this.enChargement = false;
      }
    });
  }

  /**
   * Ouvre les détails du patient (dossier)
   * @param patient Le patient dont on veut voir le dossier
   */
  ouvrirDossierPatient(patient: Patient): void {
    console.log(`📁 Ouverture du dossier du patient: ${patient.prenom} ${patient.nom}`);
    this.router.navigate(['/patients', patient.id, 'parametres-carnet']);
  }

  /**
   * Applique le filtre de recherche et le tri à la liste des patients
   */
  appliquerFiltreEtTri(): void {
    // Filtrer par terme de recherche
    let patientsFiltresTemp = this.patients.filter(patient => {
      const termeRechercheMin = this.termeRecherche.toLowerCase();
      return (
        patient.nom?.toLowerCase().includes(termeRechercheMin) ||
        patient.prenom?.toLowerCase().includes(termeRechercheMin) ||
        patient.numero_dossier?.toLowerCase().includes(termeRechercheMin) ||
        patient.telephone?.includes(this.termeRecherche) ||
        patient.email?.toLowerCase().includes(termeRechercheMin)
      );
    });

    // Appliquer le tri
    patientsFiltresTemp.sort((a, b) => {
      let valeurA: string | number = '';
      let valeurB: string | number = '';

      switch (this.critereTri) {
        case 'nom':
          valeurA = `${a.nom} ${a.prenom}`.toLowerCase();
          valeurB = `${b.nom} ${b.prenom}`.toLowerCase();
          break;
        case 'prenom':
          valeurA = `${a.prenom} ${a.nom}`.toLowerCase();
          valeurB = `${b.prenom} ${b.nom}`.toLowerCase();
          break;
        case 'dossier':
          valeurA = a.numero_dossier || '';
          valeurB = b.numero_dossier || '';
          break;
        default:
          valeurA = `${a.nom} ${a.prenom}`.toLowerCase();
          valeurB = `${b.nom} ${b.prenom}`.toLowerCase();
      }

      let resultat = 0;
      if (valeurA < valeurB) resultat = -1;
      else if (valeurA > valeurB) resultat = 1;

      return this.ordreTri === 'asc' ? resultat : -resultat;
    });

    this.patientsFiltres = patientsFiltresTemp;
  }

  /**
   * Gère le changement de terme de recherche
   */
  onRechercheChange(): void {
    this.appliquerFiltreEtTri();
  }

  /**
   * Change le critère de tri
   * @param critere Le nouveau critère de tri
   */
  changerCritereTri(critere: string): void {
    if (this.critereTri === critere) {
      // Inverser l'ordre de tri si même critère
      this.ordreTri = this.ordreTri === 'asc' ? 'desc' : 'asc';
    } else {
      this.critereTri = critere;
      this.ordreTri = 'asc';
    }
    this.appliquerFiltreEtTri();
  }

  /**
   * Retourne l'icône de tri pour un critère donné
   * @param critere Le critère de tri
   */
  getIconeTri(critere: string): string {
    if (this.critereTri !== critere) return 'bi bi-arrow-down-up';
    return this.ordreTri === 'asc' ? 'bi bi-arrow-up' : 'bi bi-arrow-down';
  }

  /**
   * Extrait l'initiale du patient pour l'afficher dans le badge
   * @param patient Le patient concerné
   * @returns L'initiale en majuscule ou '?' par défaut
   */
  obtenirInitialePatient(patient: Patient): string {
    const initialeNom = patient.nom?.[0];
    const initialePrenom = patient.prenom?.[0];
    
    // Priorité au nom, sinon prénom, sinon '?' par défaut
    const initiale = initialeNom || initialePrenom || '?';
    
    return initiale.toUpperCase();
  }

  /**
   * Fonction de tracking pour optimiser le rendu de la boucle ngFor
   * @param index Index de l'élément
   * @param patient Objet patient
   * @returns L'identifiant unique du patient
   */
  suivreParIdPatient(index: number, patient: Patient): number {
    return patient.id;
  }

  /**
   * Gère les erreurs de chargement de l'image du dossier
   * @param evenement Événement d'erreur de l'image
   */
  gererErreurImage(evenement: Event): void {
    const image = evenement.target as HTMLImageElement;
    console.error('❌ Erreur de chargement de l\'image folder.png:', this.cheminImageDossier);
    
    // Masquer l'image en erreur et afficher un message
    image.style.display = 'none';
    
    // Optionnel: utiliser une image de secours avec une icône SVG
    image.parentElement?.classList.add('image-erreur');
  }

  // ========================================
  // MÉTHODES PRIVÉES
  // ========================================

  /**
   * Démarre l'auto-rafraîchissement toutes les 30 secondes
   */
  private demarrerAutoRafraichissement(): void {
    console.log('Démarrage de l\'auto-rafraîchissement (30 secondes)');
    this.abonnementRafraichissement = interval(30000).subscribe(() => {
      console.log('Auto-rafraîchissement des carnets...');
      this.chargerLesCarnets();
    });
  }

  /**
   * Arrête l'auto-rafraîchissement
   */
  private arreterAutoRafraichissement(): void {
    if (this.abonnementRafraichissement) {
      this.abonnementRafraichissement.unsubscribe();
      this.abonnementRafraichissement = null;
      console.log('Auto-rafraîchissement arrêté');
    }
  }

  // ========================================
  // GETTERS POUR LE TEMPLATE
  // ========================================
  
  /** Retourne le chemin de l'image du dossier pour le template */
  get cheminImageDossierPourTemplate(): string {
    return this.cheminImageDossier;
  }
}

// #EbaJioloLewis
