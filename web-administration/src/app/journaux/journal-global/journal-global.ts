import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';

import { EntreeJournal, Journaux } from '../../noyau/services/journaux';

@Component({
  selector: 'app-journal-global',
  imports: [CommonModule],
  templateUrl: './journal-global.html',
  styleUrl: './journal-global.scss',
})
export class JournalGlobal implements OnInit {
  private readonly journaux = inject(Journaux);
  logs: EntreeJournal[] = [];

  ngOnInit(): void {
    this.journaux.lister().subscribe({
      next: (items) => (this.logs = items),
    });
  }
}

// #EbaJioloLewis
