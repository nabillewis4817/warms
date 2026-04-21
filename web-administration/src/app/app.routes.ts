import { Routes } from '@angular/router';
import { Connexion } from './authentification/connexion/connexion';
import { TableauDeBord } from './tableau-de-bord/tableau-de-bord/tableau-de-bord';
import { ProfilUtilisateur } from './parametres/profil-utilisateur/profil-utilisateur';
import { VueGenerale } from './statistiques/vue-generale/vue-generale';
import { authentificationGuard } from './noyau/gardes/authentification-guard';
import { roleGuard } from './noyau/gardes/role-guard';

export const routes: Routes = [
  { path: 'connexion', component: Connexion },
  { path: '', pathMatch: 'full', redirectTo: 'tableau-de-bord' },
  { path: 'tableau-de-bord', component: TableauDeBord, canActivate: [authentificationGuard] },
  {
    path: 'statistiques',
    component: VueGenerale,
    canActivate: [authentificationGuard, roleGuard],
    data: { roles: ['chirurgien_dentiste', 'secretaire'] },
  },
  { path: 'parametres/profil', component: ProfilUtilisateur, canActivate: [authentificationGuard] },
];
