import { Routes } from '@angular/router';
import { Connexion } from './authentification/connexion/connexion';
import { TableauDeBord } from './tableau-de-bord/tableau-de-bord/tableau-de-bord';
import { ProfilUtilisateur } from './parametres/profil-utilisateur/profil-utilisateur';
import { VueGenerale } from './statistiques/vue-generale/vue-generale';
import { ListePatients } from './patients/liste-patients/liste-patients';
import { NouveauPatient } from './patients/nouveau-patient/nouveau-patient';
import { DossierPatient } from './patients/dossier-patient/dossier-patient';
import { ListeConversations } from './messagerie/liste-conversations/liste-conversations';
import { FilMessages } from './messagerie/fil-messages/fil-messages';
import { JournauxComponent } from './journaux/journaux.component';
import { Inscription } from './authentification/inscription/inscription';
import { MotDePasseOublie } from './authentification/mot-de-passe-oublie/mot-de-passe-oublie';
import { PersonnelComponent } from './personnel/personnel.component';
import { Carnets } from './patients/carnets/carnets';
import { ParametresCarnet } from './patients/parametres-carnet/parametres-carnet';
import { Ocr } from './innovations/ocr/ocr';
import { IaWarms } from './innovations/ia-warms/ia-warms';
import { Avis } from './avis/avis';
import { ConsultationsComponent } from './consultations/consultations/consultations.component';
import { authentificationGuard } from './noyau/gardes/authentification-guard';
import { roleGuard } from './noyau/gardes/role-guard';

export const routes: Routes = [
  { path: 'connexion', component: Connexion },
  { path: 'inscription', component: Inscription },
  { path: 'mot-de-passe-oublie', component: MotDePasseOublie },
  { path: '', pathMatch: 'full', redirectTo: 'connexion' },
  { path: 'tableau-de-bord', component: TableauDeBord, canActivate: [authentificationGuard] },
  {
    path: 'statistiques',
    component: VueGenerale,
    canActivate: [authentificationGuard],
  },
  { path: 'patients', component: ListePatients, canActivate: [authentificationGuard] },
  { path: 'patients/nouveau', component: NouveauPatient, canActivate: [authentificationGuard] },
  { path: 'patients/:id/dossier', component: DossierPatient, canActivate: [authentificationGuard] },
  { path: 'patients/:id/parametres-carnet', component: ParametresCarnet, canActivate: [authentificationGuard] },
  { path: 'carnets', component: Carnets, canActivate: [authentificationGuard] },
  { path: 'ocr', component: Ocr, canActivate: [authentificationGuard] },
  { path: 'ia-warms', component: IaWarms, canActivate: [authentificationGuard] },
  { path: 'innovations/ia-warms', component: IaWarms, canActivate: [authentificationGuard] },
  { path: 'messagerie', component: ListeConversations, canActivate: [authentificationGuard] },
  { path: 'messagerie/conversation/:id', component: FilMessages, canActivate: [authentificationGuard] },
  { path: 'journaux', component: JournauxComponent, canActivate: [authentificationGuard] },
  { path: 'avis', component: Avis, canActivate: [authentificationGuard] },
  { path: 'personnel', component: PersonnelComponent, canActivate: [authentificationGuard] },
  { path: 'parametres/profil', component: ProfilUtilisateur, canActivate: [authentificationGuard] },
  // Routes pour les consultations et gestion clinique
  { 
    path: 'consultations', 
    component: ConsultationsComponent, 
    canActivate: [authentificationGuard]
  },
  // Routes pour les rendez-vous
  { 
    path: 'rendez-vous', 
    component: ConsultationsComponent, 
    canActivate: [authentificationGuard]
  },
  // Routes pour les appels et absences
  { 
    path: 'appels', 
    component: ConsultationsComponent, 
    canActivate: [authentificationGuard]
  },
  // Routes pour les taux d'absentéisme
  { 
    path: 'taux-absenteisme', 
    component: ConsultationsComponent, 
    canActivate: [authentificationGuard]
  },
];
