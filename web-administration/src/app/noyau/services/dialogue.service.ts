import { Injectable } from '@angular/core';
import { Observable, Subject } from 'rxjs';

export interface DialogueOptions {
  titre: string;
  message: string;
  type?: 'confirmation' | 'information' | 'erreur' | 'succes';
  boutonOk?: string;
  boutonAnnuler?: string;
}

export interface DialogueResult {
  confirme: boolean;
}

@Injectable({
  providedIn: 'root'
})
export class DialogueService {
  private dialogueSubject = new Subject<DialogueOptions>();
  private resultatSubject = new Subject<DialogueResult>();

  dialogue$ = this.dialogueSubject.asObservable();
  resultat$ = this.resultatSubject.asObservable();

  confirmer(options: Omit<DialogueOptions, 'type'>): Observable<boolean> {
    return new Observable<boolean>((observer) => {
      const dialogueOptions: DialogueOptions = {
        ...options,
        type: 'confirmation',
        boutonOk: options.boutonOk || 'Confirmer',
        boutonAnnuler: options.boutonAnnuler || 'Annuler'
      };

      // Écouter la réponse une seule fois
      const subscription = this.resultat$.subscribe((resultat: DialogueResult) => {
        observer.next(resultat.confirme);
        observer.complete();
        subscription.unsubscribe();
      });

      // Afficher le dialogue
      this.dialogueSubject.next(dialogueOptions);
    });
  }

  informer(options: Omit<DialogueOptions, 'type'>): Observable<void> {
    return new Observable<void>((observer) => {
      const dialogueOptions: DialogueOptions = {
        ...options,
        type: 'information',
        boutonOk: options.boutonOk || 'OK'
      };

      const subscription = this.resultat$.subscribe(() => {
        observer.next();
        observer.complete();
        subscription.unsubscribe();
      });

      this.dialogueSubject.next(dialogueOptions);
    });
  }

  erreur(options: Omit<DialogueOptions, 'type'>): Observable<void> {
    return new Observable<void>((observer) => {
      const dialogueOptions: DialogueOptions = {
        ...options,
        type: 'erreur',
        boutonOk: options.boutonOk || 'OK'
      };

      const subscription = this.resultat$.subscribe(() => {
        observer.next();
        observer.complete();
        subscription.unsubscribe();
      });

      this.dialogueSubject.next(dialogueOptions);
    });
  }

  succes(options: Omit<DialogueOptions, 'type'>): Observable<void> {
    return new Observable<void>((observer) => {
      const dialogueOptions: DialogueOptions = {
        ...options,
        type: 'succes',
        boutonOk: options.boutonOk || 'OK'
      };

      const subscription = this.resultat$.subscribe(() => {
        observer.next();
        observer.complete();
        subscription.unsubscribe();
      });

      this.dialogueSubject.next(dialogueOptions);
    });
  }

  // Méthode pour fermer le dialogue avec un résultat
  fermerAvecResultat(confirme: boolean): void {
    this.resultatSubject.next({ confirme });
  }
}
