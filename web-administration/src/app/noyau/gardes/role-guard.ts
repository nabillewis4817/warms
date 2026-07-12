import { CanActivateFn } from '@angular/router';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { map, of, switchMap } from 'rxjs';

import { Authentification } from '../services/authentification';

export const roleGuard: CanActivateFn = (route, _state) => {
  const auth = inject(Authentification);
  const router = inject(Router);
  const rolesAttendus = (route.data?.['roles'] ?? []) as string[];

  const verifier = (role: string | undefined) => {
    if (rolesAttendus.length === 0 || (role && rolesAttendus.includes(role))) {
      return true;
    }
    router.navigate(['/tableau-de-bord']);
    return false;
  };

  // Si le profil est déjà chargé, vérification synchrone immédiate
  const utilisateur = auth.utilisateur();
  if (utilisateur) {
    return verifier(utilisateur.role);
  }

  // Profil absent (rechargement de page F5) : le charger d'abord, puis vérifier
  return auth.chargerProfil().pipe(
    map(profil => verifier(profil?.role)),
  );
};

// #EbaJioloLewis
