import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';

import {
  PatchPreferencesPayload,
  PreferencesUtilisateurService,
  ProfilUtilisateur as ProfilUtilisateurDto,
} from '../../noyau/services/preferences-utilisateur';
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
  readonly themeService = inject(ThemeService);
  readonly traductionService = inject(TraductionService);

  enChargement = false;
  message = '';
  profil: ProfilUtilisateurDto | null = null;

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
    this.preferencesService.mettreAJourPreferences(payload).subscribe({
      next: () => {
        this.themeService.appliquer(!!payload.mode_sombre);
        this.traductionService.definirLangue(payload.langue_interface ?? 'fr');
        this.message = 'Paramètres enregistrés avec succès.';
      },
      error: () => {
        this.message = "Échec de l'enregistrement des paramètres.";
      },
    });
  }
}

// #EbaJioloLewis
