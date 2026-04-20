import { HttpInterceptorFn } from '@angular/common/http';

export const erreurInterceptor: HttpInterceptorFn = (req, next) => {
  return next(req);
};
