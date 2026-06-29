import { Injectable, signal } from '@angular/core';

type Langue = 'fr' | 'en';

const DICTIONNAIRE: Record<Langue, Record<string, string>> = {
  fr: {
    appTitle: "Wam's Cabinet",
    clinicSubtitle: 'Cabinet dentaire',
    dashboard: 'Tableau de bord',
    settings: 'Paramètres',
    profile: 'Profil utilisateur',
    darkMode: 'Mode sombre',
    language: 'Langue',
    save: 'Enregistrer',

    navGeneral: 'Général',
    navPatients: 'Patients',
    navCommunication: 'Communication',
    navAdministration: 'Administration',

    statistics: 'Statistiques',
    patients: 'Patients',
    newPatient: 'Nouveau patient',
    notebooks: 'Carnets',
    prescriptions: 'Prescriptions',
    messaging: 'Messagerie',
    reviews: 'Avis',
    staff: 'Personnel',
    logs: 'Journaux',
    agenda: 'Agenda',

    quickActions: 'Actions rapides',
    logout: 'Déconnexion',
    notifications: 'Notifications',

    tabProfile: 'Profil',
    tabAppearance: 'Apparence',
    tabNotifications: 'Notifications',
    tabPrivacy: 'Confidentialité',
    tabBackup: 'Sauvegarde',
    appearanceTitle: 'Apparence et langue',
    interfaceLanguage: "Langue de l'interface",
    lightMode: 'Mode clair',
    colorTheme: 'Thème de couleur',
  },
  en: {
    appTitle: "Wam's Clinic",
    clinicSubtitle: 'Dental practice',
    dashboard: 'Dashboard',
    settings: 'Settings',
    profile: 'User profile',
    darkMode: 'Dark mode',
    language: 'Language',
    save: 'Save',

    navGeneral: 'General',
    navPatients: 'Patients',
    navCommunication: 'Communication',
    navAdministration: 'Administration',

    statistics: 'Statistics',
    patients: 'Patients',
    newPatient: 'New patient',
    notebooks: 'Notebooks',
    prescriptions: 'Prescriptions',
    messaging: 'Messaging',
    reviews: 'Reviews',
    staff: 'Staff',
    logs: 'Logs',
    agenda: 'Agenda',

    quickActions: 'Quick actions',
    logout: 'Logout',
    notifications: 'Notifications',

    tabProfile: 'Profile',
    tabAppearance: 'Appearance',
    tabNotifications: 'Notifications',
    tabPrivacy: 'Privacy',
    tabBackup: 'Backup',
    appearanceTitle: 'Appearance and language',
    interfaceLanguage: 'Interface language',
    lightMode: 'Light mode',
    colorTheme: 'Color theme',
  },
};

@Injectable({
  providedIn: 'root',
})
export class TraductionService {
  readonly langue = signal<Langue>('fr');

  definirLangue(langue: Langue): void {
    this.langue.set(langue);
    localStorage.setItem('warms_langue', langue);
  }

  t(cle: string): string {
    return DICTIONNAIRE[this.langue()][cle] ?? cle;
  }
}

// #EbaJioloLewis
