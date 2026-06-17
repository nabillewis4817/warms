import { CanActivateFn } from '@angular/router';
import { inject } from '@angular/core';
import { Router } from '@angular/router';

import { Authentification } from '../services/authentification';

export const authentificationGuard: CanActivateFn = (route, state) => {
  const auth = inject(Authentification);
  const router = inject(Router);
  if (auth.estConnecte()) return true;
  router.navigate(['/']);
  return false;
};

// #EbaJioloLewis
