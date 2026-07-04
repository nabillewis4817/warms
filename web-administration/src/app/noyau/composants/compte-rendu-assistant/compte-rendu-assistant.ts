import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';

import {
  CompteRendu,
  CompteRenduAssistantService,
  CompteRenduPayload,
  ContexteAction,
} from '../../services/compte-rendu-assistant.service';

type EtatModal =
  | 'ferme'
  | 'parole'      // l'IA "parle" à l'acteur
  | 'generation'  // génération en cours
  | 'edition'     // texte généré, éditable
  | 'historique'; // liste des CR existants

@Component({
  selector: 'app-compte-rendu-assistant',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './compte-rendu-assistant.html',
  styleUrl: './compte-rendu-assistant.scss',
})
export class CompteRenduAssistant implements OnInit, OnDestroy {
  private readonly service = inject(CompteRenduAssistantService);
  private sub?: Subscription;

  etat: EtatModal = 'ferme';
  contexte?: ContexteAction;

  contenuEdite  = '';
  titreEdite    = '';
  genereParIa   = false;

  enregistrementEnCours = false;
  pdfEnCours: number | null = null;
  suppressionEnCours: number | null = null;
  messageRetour = '';
  messageRetourSucces = false;

  crSauvegarde?: CompteRendu;       // après sauvegarde
  historique: CompteRendu[] = [];
  chargementHistorique = false;
  crEnEdition?: CompteRendu;        // pour édition depuis historique

  // Texte de salutation animé
  phraseParole = '';
  private readonly DELAI_PAROLE = 1800; // ms avant de passer à génération

  ngOnInit(): void {
    this.sub = this.service.declencheur$.subscribe((ctx) => this._ouvrir(ctx));
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }

  private _ouvrir(ctx: ContexteAction): void {
    this.contexte = ctx;
    this.crSauvegarde = undefined;
    this.crEnEdition  = undefined;
    this.contenuEdite = '';
    this.titreEdite   = this._titreParDefaut(ctx);
    this.messageRetour = '';
    this.genereParIa = false;
    this.etat = 'parole';
    this.phraseParole = this._construirePhrase(ctx);

    setTimeout(() => this._lancerGeneration(), this.DELAI_PAROLE);
  }

  private _construirePhrase(ctx: ContexteAction): string {
    const types: Record<string, string> = {
      consultation:    'consultation',
      rendez_vous:     'rendez-vous',
      operation:       'opération',
      schema_dentaire: 'mise à jour du schéma dentaire',
      autre:           'acte clinique',
    };
    const type  = types[ctx.type_action] ?? 'acte';
    const prenom = ctx.patient_prenom || '';
    const nom    = ctx.patient_nom    || '';
    return `${type.charAt(0).toUpperCase() + type.slice(1)} terminée pour ${prenom} ${nom}. Je génère le compte-rendu…`;
  }

  private _titreParDefaut(ctx: ContexteAction): string {
    const types: Record<string, string> = {
      consultation:    'CR Consultation',
      rendez_vous:     'CR Rendez-vous',
      operation:       'CR Opération',
      schema_dentaire: 'CR Schéma dentaire',
      autre:           'Compte-rendu',
    };
    const date = ctx.date
      ? new Date(ctx.date).toLocaleDateString('fr-FR')
      : new Date().toLocaleDateString('fr-FR');
    const patient = `${ctx.patient_prenom} ${ctx.patient_nom}`.trim();
    return `${types[ctx.type_action] ?? 'Compte-rendu'} — ${patient} — ${date}`;
  }

  private _lancerGeneration(): void {
    if (!this.contexte) return;
    this.etat = 'generation';
    this.service.generer(this.contexte).subscribe({
      next: (res) => {
        this.contenuEdite = res.contenu;
        this.genereParIa  = res.genere_par_ia;
        this.etat = 'edition';
      },
      error: () => {
        this.contenuEdite = this._templateVide();
        this.genereParIa  = false;
        this.etat = 'edition';
      },
    });
  }

  private _templateVide(): string {
    return (
      '**COMPTE-RENDU CLINIQUE**\n\n'
      + '**Contexte**\n[À compléter]\n\n'
      + '**Constatations / Observations**\n[À compléter]\n\n'
      + '**Actes réalisés**\n[À compléter]\n\n'
      + '**Diagnostic / Conclusion**\n[À compléter]\n\n'
      + '**Recommandations / Suite**\n[À compléter]'
    );
  }

  enregistrer(): void {
    if (!this.contexte || this.enregistrementEnCours) return;
    this.enregistrementEnCours = true;
    this.messageRetour = '';

    const payload: CompteRenduPayload = {
      patient:      this.contexte.patient_id,
      type_action:  this.contexte.type_action,
      reference_id: this.contexte.reference_id ?? null,
      titre:        this.titreEdite || this._titreParDefaut(this.contexte),
      contenu:      this.contenuEdite,
      genere_par_ia: this.genereParIa,
    };

    const requete = this.crSauvegarde
      ? this.service.modifier(this.crSauvegarde.id, { titre: payload.titre, contenu: payload.contenu })
      : this.service.creer(payload);

    requete.subscribe({
      next: (cr) => {
        this.enregistrementEnCours = false;
        this.crSauvegarde = cr;
        this._afficherMessage('Compte-rendu enregistré avec succès.', true);
      },
      error: () => {
        this.enregistrementEnCours = false;
        this._afficherMessage("Impossible d'enregistrer le compte-rendu.", false);
      },
    });
  }

  telechargerPdf(id: number): void {
    this.pdfEnCours = id;
    this.service.telechargerPdf(id).subscribe({
      next: (blob) => {
        this.pdfEnCours = null;
        window.open(URL.createObjectURL(blob), '_blank');
      },
      error: () => {
        this.pdfEnCours = null;
        this._afficherMessage('Impossible de générer le PDF.', false);
      },
    });
  }

  ouvrirHistorique(): void {
    if (!this.contexte) return;
    this.etat = 'historique';
    this.chargementHistorique = true;
    this.service.listerPatient(this.contexte.patient_id).subscribe({
      next: (crs) => { this.historique = crs; this.chargementHistorique = false; },
      error: ()   => { this.historique = [];  this.chargementHistorique = false; },
    });
  }

  editerDepuisHistorique(cr: CompteRendu): void {
    this.crEnEdition   = cr;
    this.crSauvegarde  = cr;
    this.titreEdite    = cr.titre;
    this.contenuEdite  = cr.contenu;
    this.genereParIa   = cr.genere_par_ia;
    this.etat = 'edition';
  }

  supprimerCr(cr: CompteRendu): void {
    this.suppressionEnCours = cr.id;
    this.service.supprimer(cr.id).subscribe({
      next: () => {
        this.suppressionEnCours = null;
        this.historique = this.historique.filter((h) => h.id !== cr.id);
        if (this.crSauvegarde?.id === cr.id) this.crSauvegarde = undefined;
        this._afficherMessage('Compte-rendu supprimé.', true);
      },
      error: () => {
        this.suppressionEnCours = null;
        this._afficherMessage('Impossible de supprimer.', false);
      },
    });
  }

  regenerer(): void {
    if (!this.contexte) return;
    this.crSauvegarde = undefined;
    this._lancerGeneration();
  }

  retourEdition(): void {
    this.etat = 'edition';
  }

  fermer(): void {
    this.etat = 'ferme';
  }

  libelleType(type: string): string {
    const map: Record<string, string> = {
      consultation:    'Consultation',
      rendez_vous:     'Rendez-vous',
      operation:       'Opération',
      schema_dentaire: 'Schéma dentaire',
      autre:           'Autre',
    };
    return map[type] ?? type;
  }

  private _afficherMessage(msg: string, succes: boolean): void {
    this.messageRetour = msg;
    this.messageRetourSucces = succes;
    setTimeout(() => { if (this.messageRetour === msg) this.messageRetour = ''; }, 4000);
  }
}

// #EbaJioloLewis
