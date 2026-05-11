import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { Router } from '@angular/router';

import {
  PatchPreferencesPayload,
  PreferencesUtilisateurService,
  ProfilUtilisateur as ProfilUtilisateurDto,
} from '../../noyau/services/preferences-utilisateur';
import { Authentification } from '../../noyau/services/authentification';
import { ThemeService } from '../../noyau/services/theme';
import { TraductionService } from '../../noyau/services/traduction';

@Component({
  selector: 'app-profil-utilisateur',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './profil-utilisateur.html',
  styleUrl: './profil-utilisateur.scss',
})
export class ProfilUtilisateur implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly preferencesService = inject(PreferencesUtilisateurService);
  private readonly authService = inject(Authentification);
  private readonly router = inject(Router);
  readonly themeService = inject(ThemeService);
  readonly traductionService = inject(TraductionService);

  enChargement = false;
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
    notif_email: [true],
    notif_sms: [false],
    notif_push: [true],
    notif_rappels_auto: [true],
  });

  ngOnInit(): void {
    this.charger();
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
          notif_email: profil.preferences_notifications?.email ?? true,
          notif_sms: profil.preferences_notifications?.sms ?? false,
          notif_push: profil.preferences_notifications?.push ?? true,
          notif_rappels_auto: profil.preferences_notifications?.rappels_auto ?? true,
        });
        this.themeService.appliquer(!!profil.mode_sombre);
        this.traductionService.definirLangue((profil.langue_interface ?? 'fr') as 'fr' | 'en');
        this.enChargement = false;
      },
      error: () => {
        this.message = "Impossible de charger le profil. Vérifie l'authentification API.";
        this.enChargement = false;
      },
    });
  }

  enregistrer(): void {
    const v = this.form.getRawValue();
    const payload: PatchPreferencesPayload = {
      first_name: v.first_name || '',
      last_name: v.last_name || '',
      email: v.email || '',
      telephone: v.telephone || '',
      langue_interface: (v.langue_interface === 'en' ? 'en' : 'fr'),
      mode_sombre: !!v.mode_sombre,
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
        this.traductionService.definirLangue(payload.langue_interface ?? 'fr');
        this.message = 'Paramètres enregistrés avec succès.';
        this.charger();
      },
      error: () => {
        this.message = "Échec de l'enregistrement des paramètres.";
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
    if (payload.preferences_notifications !== undefined) {
      formData.append('preferences_notifications', JSON.stringify(payload.preferences_notifications));
    }
    formData.append('photo_profil', file);
    return this.preferencesService.mettreAJourPreferencesMultipart(formData);
  }

  onPhotoSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      this.message = 'Veuillez sélectionner une image valide.';
      input.value = '';
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      this.message = 'Image trop volumineuse (max 5MB).';
      input.value = '';
      return;
    }
    this.photoFile = file;
    const reader = new FileReader();
    reader.onload = () => {
      this.photoPreview = String(reader.result);
    };
    reader.readAsDataURL(file);
    input.value = '';
  }

  supprimerPhoto(): void {
    this.photoPreview = null;
    this.photoFile = null;
    const v = this.form.getRawValue();
    const payload: PatchPreferencesPayload = {
      first_name: v.first_name || '',
      last_name: v.last_name || '',
      email: v.email || '',
      telephone: v.telephone || '',
      langue_interface: (v.langue_interface === 'en' ? 'en' : 'fr'),
      mode_sombre: !!v.mode_sombre,
      preferences_notifications: {
        email: !!v.notif_email,
        sms: !!v.notif_sms,
        push: !!v.notif_push,
        rappels_auto: !!v.notif_rappels_auto,
      },
      // convention: chaîne vide pour vider l'image
      // backend serializer applique update partiel sur champ image
    };
    const formData = new FormData();
    formData.append('first_name', payload.first_name ?? '');
    formData.append('last_name', payload.last_name ?? '');
    formData.append('email', payload.email ?? '');
    formData.append('telephone', payload.telephone ?? '');
    formData.append('langue_interface', payload.langue_interface ?? 'fr');
    formData.append('mode_sombre', String(!!payload.mode_sombre));
    formData.append('preferences_notifications', JSON.stringify(payload.preferences_notifications ?? {}));
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

  deconnexion(): void {
    this.authService.deconnexion();
    this.router.navigate(['/connexion']);
  }

  exporterPreferences(): void {
    const data = {
      exportedAt: new Date().toISOString(),
      preferences: this.form.getRawValue(),
      profil: this.profil,
    };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `warms-preferences-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    this.message = 'Préférences exportées.';
  }

  importerPreferences(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const parsed = JSON.parse(String(reader.result));
        const prefs = parsed?.preferences;
        if (!prefs || typeof prefs !== 'object') {
          throw new Error('Format invalide');
        }
        this.form.patchValue({
          langue_interface: prefs.langue_interface ?? 'fr',
          mode_sombre: !!prefs.mode_sombre,
          notif_email: !!prefs.notif_email,
          notif_sms: !!prefs.notif_sms,
          notif_push: !!prefs.notif_push,
          notif_rappels_auto: !!prefs.notif_rappels_auto,
        });
        this.message = 'Préférences importées. Clique sur Enregistrer pour appliquer.';
      } catch {
        this.message = 'Fichier de préférences invalide.';
      } finally {
        input.value = '';
      }
    };
    reader.readAsText(file);
  }
}

// #EbaJioloLewis
