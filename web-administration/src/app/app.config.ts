import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { provideRouter } from '@angular/router';

import { routes } from './app.routes';
import { erreurInterceptor } from './noyau/intercepteurs/erreur-interceptor';
import { jwtInterceptor } from './noyau/intercepteurs/jwt-interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideHttpClient(withInterceptors([jwtInterceptor, erreurInterceptor])),
    provideRouter(routes)
  ]
};
