import { Routes } from '@angular/router';
import { Accueil } from './authentification/accueil/accueil';
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
import { Ocr } from './innovations/ocr/ocr';
import { IaWarms } from './innovations/ia-warms/ia-warms';
import { Avis } from './avis/avis';
import { ConsultationsComponent } from './consultations/consultations/consultations.component';
import { PrescriptionsComponent } from './prescriptions/prescriptions/prescriptions.component';
import { RendezVousComponent } from './rendez-vous/rendez-vous/rendez-vous';
import { AppelsComponent } from './appels/appels/appels';
import { TauxAbsenteismeComponent } from './taux-absenteisme/taux-absenteisme/taux-absenteisme';
import { Agenda } from './agenda/agenda';
import { authentificationGuard } from './noyau/gardes/authentification-guard';
import { roleGuard } from './noyau/gardes/role-guard';

export const routes: Routes = [
  { path: '', component: Accueil, pathMatch: 'full' },
  { path: 'connexion', component: Connexion },
  { path: 'inscription', component: Inscription },
  { path: 'mot-de-passe-oublie', component: MotDePasseOublie },
  { path: 'tableau-de-bord', component: TableauDeBord, canActivate: [authentificationGuard] },
  {
    path: 'statistiques',
    component: VueGenerale,
    canActivate: [authentificationGuard],
  },
  { path: 'agenda', component: Agenda, canActivate: [authentificationGuard] },
  { path: 'patients', component: ListePatients, canActivate: [authentificationGuard] },
  { path: 'patients/nouveau', component: NouveauPatient, canActivate: [authentificationGuard] },
  { path: 'patients/:id/dossier', component: DossierPatient, canActivate: [authentificationGuard] },
  { path: 'carnets', component: Carnets, canActivate: [authentificationGuard] },
  { path: 'ocr', component: Ocr, canActivate: [authentificationGuard] },
  { path: 'ia-warms', component: IaWarms, canActivate: [authentificationGuard] },
  { path: 'innovations/ia-warms', component: IaWarms, canActivate: [authentificationGuard] },
  { path: 'messagerie', component: ListeConversations, canActivate: [authentificationGuard] },
  { path: 'messagerie/conversation/:id', component: FilMessages, canActivate: [authentificationGuard] },
  { path: 'journaux', component: JournauxComponent, canActivate: [authentificationGuard] },
  { path: 'avis', component: Avis, canActivate: [authentificationGuard] },
  { path: 'prescriptions', component: PrescriptionsComponent, canActivate: [authentificationGuard] },
  { path: 'personnel', component: PersonnelComponent, canActivate: [authentificationGuard] },
  { path: 'parametres', redirectTo: 'parametres/profil', pathMatch: 'full' },
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
    component: RendezVousComponent, 
    canActivate: [authentificationGuard]
  },
  // Routes pour les appels et absences
  { 
    path: 'appels', 
    component: AppelsComponent, 
    canActivate: [authentificationGuard]
  },
  // Routes pour les taux d'absentéisme
  { 
    path: 'taux-absenteisme', 
    component: TauxAbsenteismeComponent, 
    canActivate: [authentificationGuard]
  },
];
