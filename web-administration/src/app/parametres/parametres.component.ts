import { CommonModule } from '@angular/common';
import { Component, OnInit } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { Authentification } from '../noyau/services/authentification';

@Component({
  selector: 'app-parametres',
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './parametres.component.html',
  styleUrl: './parametres.component.scss'
})
export class ParametresComponent implements OnInit {
  profileForm: any;
  utilisateur: any = null;
  photoPreview: string | null = null;
  enSauvegarde = false;
  message = '';
  
  constructor(
    private fb: FormBuilder,
    private authService: Authentification,
    private router: Router
  ) {
    this.profileForm = this.fb.group({
      nom: ['', Validators.required],
      prenom: ['', Validators.required],
      email: ['', [Validators.required, Validators.email]],
      telephone: [''],
      role: [''],
      photo: ['']
    });
  }

  ngOnInit(): void {
    this.chargerProfil();
  }

  chargerProfil(): void {
    // Charger les données réelles de l'utilisateur connecté
    const user = this.authService.utilisateur();
    if (user) {
      this.utilisateur = {
        id: user.id,
        nom: user.nom || '',
        prenom: user.prenom || '',
        email: user.email || '',
        telephone: '', // Non disponible dans l'interface UtilisateurConnecte
        role: user.role || '',
        photo: null, // Non disponible dans l'interface UtilisateurConnecte
        dateInscription: new Date(),
        dernierConnexion: new Date()
      };
      
      this.profileForm.patchValue(this.utilisateur);
    }
  }

  onFileSelected(event: any): void {
    const file = event.target.files[0];
    if (file) {
      // Validation du fichier
      if (!file.type.startsWith('image/')) {
        this.message = 'Veuillez sélectionner une image valide';
        return;
      }
      
      if (file.size > 5 * 1024 * 1024) { // 5MB max
        this.message = 'L\'image ne doit pas dépasser 5MB';
        return;
      }
      
      // Preview de l'image
      const reader = new FileReader();
      reader.onload = (e) => {
        this.photoPreview = e.target?.result as string;
        this.profileForm.patchValue({ photo: file });
      };
      reader.readAsDataURL(file);
    }
  }

  sauvegarderProfil(): void {
    if (this.profileForm.invalid) {
      this.message = 'Veuillez corriger les erreurs dans le formulaire';
      return;
    }

    this.enSauvegarde = true;
    this.message = '';

    // Préparer les données pour l'API
    const formData = new FormData();
    const formValues = this.profileForm.value;
    
    // Ajouter les champs texte
    formData.append('nom', formValues.nom || '');
    formData.append('prenom', formValues.prenom || '');
    formData.append('email', formValues.email || '');
    formData.append('telephone', formValues.telephone || '');
    
    // Ajouter la photo si elle a été changée
    if (formValues.photo instanceof File) {
      formData.append('photo_profil', formValues.photo);
    }

    // Appeler l'API pour sauvegarder le profil
    // Note: En production, vous devriez appeler un endpoint API réel
    // Pour l'instant, nous simulons la sauvegarde
    setTimeout(() => {
      this.utilisateur = { ...this.utilisateur, ...this.profileForm.value };
      this.enSauvegarde = false;
      this.message = 'Profil mis à jour avec succès !';
      
      // Effacer le message après 3 secondes
      setTimeout(() => {
        this.message = '';
      }, 3000);
    }, 1500);
  }

  logout(): void {
    this.authService.deconnexion();
    this.router.navigate(['/connexion']);
  }

  changerMotDePasse(): void {
    // Ouvrir une modal ou naviguer vers une page de changement de mot de passe
    this.message = 'Fonction de changement de mot de passe bientôt disponible';
    setTimeout(() => {
      this.message = '';
    }, 3000);
  }

  supprimerPhoto(): void {
    this.photoPreview = null;
    this.profileForm.patchValue({ photo: null });
    this.utilisateur.photo = null;
    this.message = 'Photo supprimée';
    setTimeout(() => {
      this.message = '';
    }, 2000);
  }

  getRoleLabel(role: string): string {
    const roles: { [key: string]: string } = {
      'chirurgien_dentiste': 'Chirurgien-Dentiste',
      'secretaire': 'Secrétaire',
      'infirmiere': 'Infirmière',
      'patient': 'Patient',
      'administrateur': 'Administrateur'
    };
    return roles[role] || role;
  }
}
