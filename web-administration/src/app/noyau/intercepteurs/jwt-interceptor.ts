import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';

import { Authentification } from '../services/authentification';

export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(Authentification);
  const token = auth.tokenAccess();
  if (!token) return next(req);

  const clone = req.clone({
    setHeaders: {
      Authorization: `Bearer ${token}`,
    },
  });
  return next(clone);
};

// #EbaJioloLewis
