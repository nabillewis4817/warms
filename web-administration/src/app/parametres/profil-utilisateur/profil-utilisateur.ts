import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';

import {
  PatchPreferencesPayload,
  PreferencesUtilisateurService,
  ProfilUtilisateur as ProfilUtilisateurDto,
} from '../../noyau/services/preferences-utilisateur';
import { Authentification } from '../../noyau/services/authentification';
import { CouleurTheme, ThemeService } from '../../noyau/services/theme';
import { TraductionService } from '../../noyau/services/traduction';
import { DialogueService } from '../../noyau/services/dialogue.service';
import { CapturePhoto } from '../../noyau/composants/capture-photo/capture-photo';

type OngletParametres = 'profil' | 'apparence' | 'notifications' | 'confidentialite' | 'sauvegarde';

@Component({
  selector: 'app-profil-utilisateur',
  imports: [CommonModule, ReactiveFormsModule, CapturePhoto],
  templateUrl: './profil-utilisateur.html',
  styleUrl: './profil-utilisateur.scss',
})
export class ProfilUtilisateur implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly preferencesService = inject(PreferencesUtilisateurService);
  private readonly authService = inject(Authentification);
  private readonly router = inject(Router);
  private readonly dialogueService = inject(DialogueService);
  readonly themeService = inject(ThemeService);
  readonly traductionService = inject(TraductionService);

  readonly onglets: { cle: OngletParametres; label: string; icone: string }[] = [
    { cle: 'profil', label: 'Profil', icone: 'bi-person-badge' },
    { cle: 'apparence', label: 'Apparence', icone: 'bi-palette' },
    { cle: 'notifications', label: 'Notifications', icone: 'bi-bell' },
    { cle: 'confidentialite', label: 'Confidentialité', icone: 'bi-shield-lock' },
    { cle: 'sauvegarde', label: 'Sauvegarde', icone: 'bi-cloud-arrow-up' },
  ];
  ongletActif: OngletParametres = 'profil';

  enChargement = false;
  enregistrementEnCours = false;
  message = '';
  profil: ProfilUtilisateurDto | null = null;
  photoPreview: string | null = null;
  photoFile: File | null = null;

  form = this.fb.group({
    first_name: [''],
    last_name: [''],
    email: [''],
    telephone: [''],
    langue_interface: ['fr'],
    mode_sombre: [false],
    theme_couleur: ['bleu' as CouleurTheme],
    notif_email: [true],
    notif_sms: [false],
    notif_push: [true],
    notif_rappels_auto: [true],
  });

  apparenceEnCours = false;

  readonly couleursDisponibles: { valeur: CouleurTheme; label: string; degrade: string }[] = [
    { valeur: 'bleu', label: 'Bleu', degrade: 'linear-gradient(135deg, #1e4db7, #ffffff)' },
    { valeur: 'vert', label: 'Vert', degrade: 'linear-gradient(135deg, #16a34a, #ffffff)' },
    { valeur: 'rouge', label: 'Rouge', degrade: 'linear-gradient(135deg, #dc2626, #ffffff)' },
    { valeur: 'rose', label: 'Rose', degrade: 'linear-gradient(135deg, #ec4899, #ffffff)' },
    { valeur: 'jaune', label: 'Jaune', degrade: 'linear-gradient(135deg, #d97706, #ffffff)' },
  ];

  // ===== Confidentialité =====
  formMotDePasse = this.fb.group({
    ancien_mot_de_passe: ['', Validators.required],
    nouveau_mot_de_passe: ['', [Validators.required, Validators.minLength(6)]],
    confirmation_mot_de_passe: ['', Validators.required],
  });
  messageSecurite = '';
  securiteSucces = false;
  securiteEnCours = false;
  afficherAncien = false;
  afficherNouveau = false;

  // ===== Sauvegarde =====
  restaurationFichier: File | null = null;
  sauvegardeEnCours = false;
  messageSauvegarde = '';
  sauvegardeSucces = false;

  get estChirurgien(): boolean {
    return this.profil?.role === 'chirurgien_dentiste';
  }

  ngOnInit(): void {
    this.charger();
  }

  changerOnglet(cle: OngletParametres): void {
    this.ongletActif = cle;
    this.message = '';
  }

  charger(): void {
    this.enChargement = true;
    this.preferencesService.obtenirMonProfil().subscribe({
      next: (profil) => {
        this.profil = profil;
        this.photoPreview = profil.photo_profil;
        this.photoFile = null;
        this.form.patchValue({
          first_name: profil.prenom,
          last_name: profil.nom,
          email: profil.email,
          telephone: profil.telephone,
          langue_interface: profil.langue_interface ?? 'fr',
          mode_sombre: !!profil.mode_sombre,
          theme_couleur: profil.theme_couleur ?? 'bleu',
          notif_email: profil.preferences_notifications?.email ?? true,
          notif_sms: profil.preferences_notifications?.sms ?? false,
          notif_push: profil.preferences_notifications?.push ?? true,
          notif_rappels_auto: profil.preferences_notifications?.rappels_auto ?? true,
        });
        this.themeService.appliquer(!!profil.mode_sombre);
        this.themeService.appliquerCouleur(profil.theme_couleur ?? 'bleu');
        this.traductionService.definirLangue((profil.langue_interface ?? 'fr') as 'fr' | 'en');
        this.enChargement = false;
      },
      error: () => {
        this.message = "Impossible de charger le profil. Vérifie l'authentification API.";
        this.enChargement = false;
      },
    });
  }

  get initiales(): string {
    const p = (this.profil?.prenom ?? '').charAt(0);
    const n = (this.profil?.nom ?? '').charAt(0);
    return (p + n).toUpperCase() || '?';
  }

  enregistrer(): void {
    this.enregistrementEnCours = true;
    const v = this.form.getRawValue();
    const payload: PatchPreferencesPayload = {
      first_name: v.first_name || '',
      last_name: v.last_name || '',
      email: v.email || '',
      telephone: v.telephone || '',
      langue_interface: (v.langue_interface === 'en' ? 'en' : 'fr'),
      mode_sombre: !!v.mode_sombre,
      theme_couleur: v.theme_couleur as CouleurTheme,
      preferences_notifications: {
        email: !!v.notif_email,
        sms: !!v.notif_sms,
        push: !!v.notif_push,
        rappels_auto: !!v.notif_rappels_auto,
      },
    };
    const request$ = this.photoFile ? this.buildMultipartRequest(payload, this.photoFile) : this.preferencesService.mettreAJourPreferences(payload);
    request$.subscribe({
      next: () => {
        this.themeService.appliquer(!!payload.mode_sombre);
        this.themeService.appliquerCouleur(payload.theme_couleur ?? 'bleu');
        this.traductionService.definirLangue(payload.langue_interface ?? 'fr');
        this.message = 'Paramètres enregistrés avec succès.';
        this.enregistrementEnCours = false;
        this.charger();
      },
      error: () => {
        this.message = "Échec de l'enregistrement des paramètres.";
        this.enregistrementEnCours = false;
      },
    });
  }

  private buildMultipartRequest(payload: PatchPreferencesPayload, file: File) {
    const formData = new FormData();
    if (payload.first_name !== undefined) formData.append('first_name', payload.first_name);
    if (payload.last_name !== undefined) formData.append('last_name', payload.last_name);
    if (payload.email !== undefined) formData.append('email', payload.email);
    if (payload.telephone !== undefined) formData.append('telephone', payload.telephone);
    if (payload.langue_interface !== undefined) formData.append('langue_interface', payload.langue_interface);
    if (payload.mode_sombre !== undefined) formData.append('mode_sombre', String(payload.mode_sombre));
    if (payload.theme_couleur !== undefined) formData.append('theme_couleur', payload.theme_couleur);
    if (payload.preferences_notifications !== undefined) {
      formData.append('preferences_notifications', JSON.stringify(payload.preferences_notifications));
    }
    formData.append('photo_profil', file);
    return this.preferencesService.mettreAJourPreferencesMultipart(formData);
  }

  // ===== Apparence : application instantanée + sauvegarde immédiate =====

  choisirModeSombre(sombre: boolean): void {
    this.form.patchValue({ mode_sombre: sombre });
    this.themeService.appliquer(sombre);
    this.sauvegarderApparenceImmediat();
  }

  choisirCouleur(couleur: CouleurTheme): void {
    this.form.patchValue({ theme_couleur: couleur });
    this.themeService.appliquerCouleur(couleur);
    this.sauvegarderApparenceImmediat();
  }

  changerLangueImmediat(langue: 'fr' | 'en'): void {
    this.form.patchValue({ langue_interface: langue });
    this.traductionService.definirLangue(langue);
    this.sauvegarderApparenceImmediat();
  }

  private sauvegarderApparenceImmediat(): void {
    this.apparenceEnCours = true;
    const v = this.form.getRawValue();
    this.preferencesService
      .mettreAJourPreferences({
        langue_interface: v.langue_interface === 'en' ? 'en' : 'fr',
        mode_sombre: !!v.mode_sombre,
        theme_couleur: v.theme_couleur as CouleurTheme,
      })
      .subscribe({
        next: () => {
          this.apparenceEnCours = false;
        },
        error: () => {
          this.apparenceEnCours = false;
          this.message = "Échec de l'enregistrement de l'apparence.";
        },
      });
  }

  onPhotoChange(fichier: File | null): void {
    if (!fichier) {
      this.supprimerPhoto();
      return;
    }
    this.photoFile = fichier;
  }

  supprimerPhoto(): void {
    this.photoPreview = null;
    this.photoFile = null;
    const v = this.form.getRawValue();
    const formData = new FormData();
    formData.append('first_name', v.first_name ?? '');
    formData.append('last_name', v.last_name ?? '');
    formData.append('email', v.email ?? '');
    formData.append('telephone', v.telephone ?? '');
    formData.append('langue_interface', v.langue_interface === 'en' ? 'en' : 'fr');
    formData.append('mode_sombre', String(!!v.mode_sombre));
    formData.append('preferences_notifications', JSON.stringify({
      email: !!v.notif_email, sms: !!v.notif_sms, push: !!v.notif_push, rappels_auto: !!v.notif_rappels_auto,
    }));
    formData.append('photo_profil', '');
    this.preferencesService.mettreAJourPreferencesMultipart(formData).subscribe({
      next: () => {
        this.message = 'Photo supprimée.';
        this.charger();
      },
      error: () => {
        this.message = 'Échec de la suppression de la photo.';
      },
    });
  }

  // ===== Confidentialité =====

  get motsDePasseDifferents(): boolean {
    const v = this.formMotDePasse.value;
    return !!v.nouveau_mot_de_passe && !!v.confirmation_mot_de_passe && v.nouveau_mot_de_passe !== v.confirmation_mot_de_passe;
  }

  changerMotDePasse(): void {
    this.securiteSucces = false;
    if (this.formMotDePasse.invalid || this.motsDePasseDifferents) {
      this.formMotDePasse.markAllAsTouched();
      this.messageSecurite = this.motsDePasseDifferents
        ? 'Les mots de passe ne correspondent pas.'
        : 'Merci de compléter correctement le formulaire.';
      return;
    }
    this.securiteEnCours = true;
    this.messageSecurite = '';
    const v = this.formMotDePasse.getRawValue();
    this.preferencesService.changerMotDePasse(v.ancien_mot_de_passe!, v.nouveau_mot_de_passe!).subscribe({
      next: () => {
        this.securiteEnCours = false;
        this.securiteSucces = true;
        this.messageSecurite = 'Mot de passe modifié avec succès.';
        this.formMotDePasse.reset();
      },
      error: (err) => {
        this.securiteEnCours = false;
        this.securiteSucces = false;
        this.messageSecurite = err?.error?.detail || 'Échec de la modification du mot de passe.';
      },
    });
  }

  deconnexion(): void {
    this.authService.deconnexion();
    this.router.navigate(['/connexion']);
  }

  demanderDeconnexion(): void {
    this.dialogueService.confirmer({
      titre: 'Se déconnecter',
      message: 'Voulez-vous vraiment vous déconnecter de WARMS sur cet appareil ?',
      boutonOk: 'Se déconnecter',
      boutonAnnuler: 'Annuler',
    }).subscribe((confirme) => {
      if (confirme) this.deconnexion();
    });
  }

  // ===== Sauvegarde =====

  exporterSauvegarde(): void {
    this.sauvegardeEnCours = true;
    this.sauvegardeSucces = false;
    this.messageSauvegarde = '';
    this.preferencesService.exporterSauvegarde().subscribe({
      next: (blob) => {
        this.sauvegardeEnCours = false;
        this.sauvegardeSucces = true;
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `warms-sauvegarde-${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        this.messageSauvegarde = 'Sauvegarde exportée avec succès.';
      },
      error: () => {
        this.sauvegardeEnCours = false;
        this.sauvegardeSucces = false;
        this.messageSauvegarde = "Échec de l'export de la sauvegarde.";
      },
    });
  }

  onFichierRestaurationSelectionne(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.restaurationFichier = input.files?.[0] ?? null;
    this.messageSauvegarde = '';
  }

  demanderRestauration(): void {
    if (!this.restaurationFichier) return;
    this.dialogueService.confirmer({
      titre: 'Restaurer une sauvegarde',
      message: `Cette action va réécrire les données existantes avec celles du fichier « ${this.restaurationFichier.name} ». Cette opération est sensible. Continuer ?`,
      boutonOk: 'Restaurer',
      boutonAnnuler: 'Annuler',
    }).subscribe((confirme) => {
      if (confirme) this.restaurerSauvegarde();
    });
  }

  private restaurerSauvegarde(): void {
    if (!this.restaurationFichier) return;
    this.sauvegardeEnCours = true;
    this.sauvegardeSucces = false;
    this.messageSauvegarde = '';
    this.preferencesService.restaurerSauvegarde(this.restaurationFichier).subscribe({
      next: (res) => {
        this.sauvegardeEnCours = false;
        this.sauvegardeSucces = true;
        this.messageSauvegarde = res.detail;
        this.restaurationFichier = null;
      },
      error: (err) => {
        this.sauvegardeEnCours = false;
        this.sauvegardeSucces = false;
        this.messageSauvegarde = err?.error?.detail || 'Échec de la restauration.';
      },
    });
  }
}

// #EbaJioloLewis
