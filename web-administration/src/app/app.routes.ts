import { Routes } from '@angular/router';
import { Connexion } from './authentification/connexion/connexion';
import { TableauDeBord } from './tableau-de-bord/tableau-de-bord/tableau-de-bord';
import { ProfilUtilisateur } from './parametres/profil-utilisateur/profil-utilisateur';
import { VueGenerale } from './statistiques/vue-generale/vue-generale';
import { ListePatients } from './patients/liste-patients/liste-patients';
import { NouveauPatient } from './patients/nouveau-patient/nouveau-patient';
import { ListeConversations } from './messagerie/liste-conversations/liste-conversations';
import { FilMessages } from './messagerie/fil-messages/fil-messages';
import { JournalGlobal } from './journaux/journal-global/journal-global';
import { Inscription } from './authentification/inscription/inscription';
import { MotDePasseOublie } from './authentification/mot-de-passe-oublie/mot-de-passe-oublie';
import { GestionPersonnel } from './personnel/gestion-personnel/gestion-personnel';
import { Carnets } from './patients/carnets/carnets';
import { ParametresCarnet } from './patients/parametres-carnet/parametres-carnet';
import { Ocr } from './innovations/ocr/ocr';
import { Avis } from './avis/avis';
import { authentificationGuard } from './noyau/gardes/authentification-guard';
import { roleGuard } from './noyau/gardes/role-guard';

export const routes: Routes = [
  { path: 'connexion', component: Connexion },
  { path: 'inscription', component: Inscription },
  { path: 'mot-de-passe-oublie', component: MotDePasseOublie },
  { path: '', pathMatch: 'full', redirectTo: 'tableau-de-bord' },
  { path: 'tableau-de-bord', component: TableauDeBord, canActivate: [authentificationGuard] },
  {
    path: 'statistiques',
    component: VueGenerale,
    canActivate: [authentificationGuard, roleGuard],
    data: { roles: ['chirurgien_dentiste', 'secretaire'] },
  },
  { path: 'patients', component: ListePatients, canActivate: [authentificationGuard] },
  { path: 'patients/nouveau', component: NouveauPatient, canActivate: [authentificationGuard] },
  { path: 'patients/:id/parametres-carnet', component: ParametresCarnet, canActivate: [authentificationGuard] },
  { path: 'carnets', component: Carnets, canActivate: [authentificationGuard] },
  { path: 'ocr', component: Ocr, canActivate: [authentificationGuard] },
  { path: 'avis', component: Avis, canActivate: [authentificationGuard, roleGuard], data: { roles: ['chirurgien_dentiste', 'secretaire'] } },
  { path: 'messagerie', component: ListeConversations, canActivate: [authentificationGuard] },
  { path: 'messagerie/conversation/:id', component: FilMessages, canActivate: [authentificationGuard] },
  { path: 'journaux', component: JournalGlobal, canActivate: [authentificationGuard, roleGuard], data: { roles: ['chirurgien_dentiste', 'secretaire'] } },
  { path: 'personnel', component: GestionPersonnel, canActivate: [authentificationGuard, roleGuard], data: { roles: ['chirurgien_dentiste', 'secretaire'] } },
  { path: 'parametres/profil', component: ProfilUtilisateur, canActivate: [authentificationGuard] },
];
