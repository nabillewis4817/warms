import { CanActivateFn } from '@angular/router';
import { inject } from '@angular/core';
import { Router } from '@angular/router';

import { Authentification } from '../services/authentification';

export const roleGuard: CanActivateFn = (route, state) => {
  const auth = inject(Authentification);
  const router = inject(Router);
  const rolesAttendus = (route.data?.['roles'] ?? []) as string[];
  const role = auth.utilisateur()?.role;

  if (rolesAttendus.length === 0 || (role && rolesAttendus.includes(role))) {
    return true;
  }
  router.navigate(['/tableau-de-bord']);
  return false;
};

// #EbaJioloLewis
