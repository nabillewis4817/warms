import { HttpInterceptorFn } from '@angular/common/http';

import { Authentification } from '../services/authentification';

export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  if (
    req.url.includes('/auth/token/') ||
    req.url.includes('/auth/register/') ||
    req.url.includes('/auth/forgot-password/') ||
    req.url.includes('/auth/reset-password/') ||
    req.url.includes('/personnel/ping/')
  ) {
    return next(req);
  }

  const token = localStorage.getItem('warms_access');
  if (!token) {
    return next(req);
  }

  return next(
    req.clone({
      setHeaders: { Authorization: `Bearer ${token}` },
    })
  );
};
