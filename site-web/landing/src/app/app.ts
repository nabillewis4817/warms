import { Component, OnInit, OnDestroy, AfterViewInit, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-root',
  imports: [CommonModule],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App implements OnInit, AfterViewInit, OnDestroy {
  menuOuvert = false;
  navTransparente = true;
  screenshotActif = 0;
  mobileActif = 0;
  statsVisibles = false;
  private statsObserver?: IntersectionObserver;
  private scrollObserver?: IntersectionObserver;

  readonly features = [
    { icone: 'bi-person-vcard-fill', titre: 'Dossiers Numériques', desc: 'Centralisez l\'intégralité des informations patient : historique, radios, prescriptions. Accessible en un clic depuis n\'importe où.', couleur: 'teal' },
    { icone: 'bi-calendar2-week-fill', titre: 'Agenda Intelligent', desc: 'Gestion des rendez-vous avec rappels automatiques, vue journalière/hebdo et synchronisation en temps réel avec toute l\'équipe.', couleur: 'blue' },
    { icone: 'bi-cpu-fill', titre: 'IA & OCR Intégrés', desc: 'Scannez un carnet médical physique et l\'IA extrait automatiquement toutes les informations patient en quelques secondes.', couleur: 'violet' },
    { icone: 'bi-capsule-pill', titre: 'Prescriptions', desc: 'Créez, suivez et modifiez les ordonnances directement depuis le dossier patient. Statuts actif/terminé/annulé en temps réel.', couleur: 'cyan' },
    { icone: 'bi-phone-fill', titre: 'Application Mobile', desc: 'Votre cabinet dans la poche. Les patients consultent leur dossier, leurs rappels médicaments et communiquent avec l\'équipe.', couleur: 'indigo' },
    { icone: 'bi-graph-up-arrow', titre: 'Statistiques & Rapports', desc: 'Tableaux de bord avec indicateurs clés : taux d\'occupation, revenus, évolution patients, absentéisme prédit par l\'IA.', couleur: 'emerald' },
  ];

  readonly screenshots = [
    { src: 'assets/web/Dashboard chirugien 1.png', label: 'Dashboard Chirurgien', desc: 'Vue d\'ensemble complète de l\'activité du cabinet' },
    { src: 'assets/web/Patients.png', label: 'Gestion Patients', desc: 'Liste intelligente avec filtres, statuts et accès rapide' },
    { src: 'assets/web/Dossiers.png', label: 'Dossiers Médicaux', desc: 'Carnet numérique complet avec QR code unique par patient' },
    { src: 'assets/web/Prescriptions.png', label: 'Prescriptions', desc: 'Suivi des ordonnances avec changement de statut instantané' },
    { src: 'assets/web/Agenda.png', label: 'Agenda', desc: 'Calendrier interactif avec gestion des rendez-vous' },
    { src: 'assets/web/OCR.png', label: 'OCR & IA', desc: 'Numérisation instantanée des carnets médicaux physiques' },
    { src: 'assets/web/Statistiques.png', label: 'Statistiques', desc: 'Analyses et indicateurs de performance du cabinet' },
    { src: 'assets/web/Messagerie.png', label: 'Messagerie', desc: 'Communication interne sécurisée entre praticiens' },
  ];

  readonly mobileScreenshots = [
    { src: "assets/mobile/dash.png", label: 'Tableau de bord' },
    { src: "assets/mobile/Wam's IA.png", label: 'Assistant IA' },
    { src: "assets/mobile/Rappels.png", label: 'Rappels médicaments' },
    { src: "assets/mobile/Messagerie.png", label: 'Messagerie' },
    { src: "assets/mobile/Avis.png", label: 'Avis & évaluations' },
    { src: "assets/mobile/settings.png", label: 'Paramètres' },
  ];

  readonly stats = [
    { valeur: 15, suffixe: '+', label: 'Modules intégrés', icone: 'bi-grid-3x3-gap-fill' },
    { valeur: 360, suffixe: '°', label: 'Gestion complète', icone: 'bi-arrow-repeat' },
    { valeur: 3, suffixe: '', label: 'Plateformes (Web, Mobile, IA)', icone: 'bi-layers-fill' },
    { valeur: 100, suffixe: '%', label: 'Données sécurisées', icone: 'bi-shield-lock-fill' },
  ];

  readonly avantages = [
    { icone: 'bi-lightning-charge-fill', titre: 'Rapide', desc: 'Interface optimisée pour la vitesse d\'exécution en cabinet' },
    { icone: 'bi-shield-check-fill', titre: 'Sécurisé', desc: 'Authentification JWT, rôles et permissions granulaires' },
    { icone: 'bi-broadcast-pin', titre: 'Temps réel', desc: 'Synchronisation instantanée sur tous les postes et mobiles' },
    { icone: 'bi-translate', titre: 'Adapté', desc: 'Conçu pour les cabinets africains, francophone natif' },
  ];

  statsAffichees: number[] = [];
  private intervalIds: any[] = [];

  ngOnInit(): void {
    this.statsAffichees = this.stats.map(() => 0);
  }

  ngAfterViewInit(): void {
    // Appelé après le rendu du DOM — toutes les directives sont présentes
    this._observerScrollReveal();
    this._observerStats();
  }

  ngOnDestroy(): void {
    this.statsObserver?.disconnect();
    this.scrollObserver?.disconnect();
    this.intervalIds.forEach(clearInterval);
  }

  @HostListener('window:scroll')
  onScroll(): void {
    this.navTransparente = window.scrollY < 60;
  }

  setScreenshot(i: number): void { this.screenshotActif = i; }
  prevScreenshot(): void { this.screenshotActif = (this.screenshotActif - 1 + this.screenshots.length) % this.screenshots.length; }
  nextScreenshot(): void { this.screenshotActif = (this.screenshotActif + 1) % this.screenshots.length; }

  setMobile(i: number): void { this.mobileActif = i; }
  prevMobile(): void { this.mobileActif = (this.mobileActif - 1 + this.mobileScreenshots.length) % this.mobileScreenshots.length; }
  nextMobile(): void { this.mobileActif = (this.mobileActif + 1) % this.mobileScreenshots.length; }

  scrollTo(id: string): void {
    this.menuOuvert = false;
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  private _observerScrollReveal(): void {
    this.scrollObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach(e => {
          if (e.isIntersecting) {
            e.target.classList.add('visible');
            this.scrollObserver?.unobserve(e.target);
          }
        });
      },
      // threshold: 0.08 → déclenche dès que 8% de l'élément est visible
      // rootMargin '-40px' évite un déclenchement trop tôt tout en restant fiable
      { threshold: 0.08, rootMargin: '0px 0px -40px 0px' }
    );

    document.querySelectorAll('.reveal').forEach(el => this.scrollObserver!.observe(el));
  }

  private _observerStats(): void {
    this.statsObserver = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !this.statsVisibles) {
          this.statsVisibles = true;
          this._animer();
        }
      },
      { threshold: 0.3 }
    );
    const el = document.getElementById('stats-section');
    if (el) this.statsObserver.observe(el);
  }

  private _animer(): void {
    this.stats.forEach((s, i) => {
      const duration = 1800;
      const steps = 60;
      const increment = s.valeur / steps;
      let current = 0;
      const id = setInterval(() => {
        current = Math.min(current + increment, s.valeur);
        this.statsAffichees[i] = Math.round(current);
        if (current >= s.valeur) clearInterval(id);
      }, duration / steps);
      this.intervalIds.push(id);
    });
  }
}
