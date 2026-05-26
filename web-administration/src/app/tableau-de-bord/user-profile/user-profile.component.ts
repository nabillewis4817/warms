import { Component, OnInit, signal, computed, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { Authentification } from '../../noyau/services/authentification';

export interface UtilisateurConnecte {
  id: number;
  username: string;
  email: string;
  prenom: string;
  nom: string;
  role: string;
  photo_profil?: string;
  telephone?: string;
  specialite?: string;
  derniere_connexion?: string;
}

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './user-profile.component.html',
  styleUrls: ['./user-profile.component.scss']
})
export class UserProfileComponent implements OnInit {
  estConnecte = signal<boolean>(false);
  utilisateur = signal<UtilisateurConnecte | null>(null);
  menuOuvert = signal<boolean>(false);
  photoUrl = signal<string>('/assets/images/default-avatar.png');

  constructor(
    private auth: Authentification,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.estConnecte.set(this.auth.estConnecte());
    const profilCache = this.auth.utilisateur();
    if (profilCache) {
      this.utilisateur.set(profilCache);
      this.genererPhotoUrl();
    }
    if (this.auth.estConnecte()) {
      this.chargerProfilUtilisateur();
    }
  }

  private chargerProfilUtilisateur(): void {
    this.auth.chargerProfil().subscribe({
      next: (profil) => {
        this.estConnecte.set(true);
        this.utilisateur.set(profil);
        this.genererPhotoUrl();
      },
      error: (error) => {
        console.error('Erreur chargement profil:', error);
        if (this.auth.estConnecte()) {
          this.estConnecte.set(true);
        }
      },
    });
  }

  private genererPhotoUrl(): void {
    const user = this.utilisateur();
    if (user?.photo_profil) {
      this.photoUrl.set(`http://127.0.0.1:8000${user.photo_profil}`);
    } else {
      // Générer avatar basé sur les initiales
      const initiales = this.genererInitiales();
      this.photoUrl.set(`https://ui-avatars.com/api/?name=${initiales}&background=1E4DB7&color=fff&size=40&font-size=0.6&bold=true`);
    }
  }

  private genererInitiales(): string {
    const user = this.utilisateur();
    if (!user) return 'U';
    
    if (user.prenom && user.nom) {
      return `${user.prenom.charAt(0)}${user.nom.charAt(0)}`.toUpperCase();
    }
    return user.username.charAt(0).toUpperCase();
  }

  basculerMenu(): void {
    this.menuOuvert.set(!this.menuOuvert());
  }

  fermerMenu(): void {
    this.menuOuvert.set(false);
  }

  naviguerVersConnexion(): void {
    this.fermerMenu();
    this.router.navigate(['/connexion']);
  }

  naviguerVersProfil(): void {
    this.fermerMenu();
    this.router.navigate(['/parametres/profil']);
  }

  naviguerVersParametres(): void {
    this.fermerMenu();
    this.router.navigate(['/parametres/profil']);
  }

  seDeconnecter(): void {
    this.fermerMenu();
    this.auth.deconnexion();
    this.router.navigate(['/connexion']);
  }

  // Computed properties pour le template
  nomAffiche = computed(() => {
    const user = this.utilisateur();
    if (!user) return 'Utilisateur';
    
    if (user.prenom && user.nom) {
      return `${user.prenom} ${user.nom}`;
    }
    return user.username;
  });

  roleAffiche = computed(() => {
    const user = this.utilisateur();
    if (!user) return '';
    
    const roles: { [key: string]: string } = {
      'administrateur': 'Administrateur',
      'chirurgien_dentiste': 'Chirurgien-Dentiste',
      'medecin': 'Médecin',
      'infirmiere': 'Infirmière',
      'assistant': 'Assistant',
      'secretaire': 'Secrétaire'
    };
    
    return roles[user.role] || user.role;
  });

  specialiteAffiche = computed(() => {
    const user = this.utilisateur();
    return user?.specialite || '';
  });

  // Gestion du clic extérieur pour fermer le menu
  @HostListener('document:click', ['$event'])
  onClickOutside(event: Event): void {
    const target = event.target as HTMLElement;
    const profileElement = document.querySelector('.user-profile');
    
    if (profileElement && !profileElement.contains(target)) {
      this.menuOuvert.set(false);
    }
  }
}
