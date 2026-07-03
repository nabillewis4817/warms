import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { Router } from '@angular/router';

import { Authentification } from '../../noyau/services/authentification';
import { DateTimeService } from '../../noyau/services/datetime.service';
import { DashboardService, DashboardStats } from '../../noyau/services/dashboard';
import { Patients, Patient } from '../../noyau/services/patients';

@Component({
  selector: 'app-dashboard-infirmiere',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './dashboard-infirmiere.html',
  styleUrls: ['./dashboard-infirmiere.scss'],
})
export class DashboardInfirmiere implements OnInit {
  readonly auth = inject(Authentification);
  private readonly router = inject(Router);
  readonly dateTimeService = inject(DateTimeService);
  private readonly dashboardService = inject(DashboardService);
  private readonly patientsService = inject(Patients);

  dashboardStats: DashboardStats | null = null;
  chargement = false;
  patientsAssignes: Patient[] = [];

  get salutation(): string {
    return this.dateTimeService.getTimeBasedGreeting();
  }

  ngOnInit(): void {
    this.charger();
    this.chargerPatientsAssignes();
  }

  charger(): void {
    this.dashboardService.getDashboardStats().subscribe({
      next: (data) => {
        this.dashboardStats = data;
      },
      error: () => {},
    });
  }

  chargerPatientsAssignes(): void {
    this.chargement = true;
    this.patientsService.lister().subscribe({
      next: (patients) => {
        this.patientsAssignes = patients.slice(0, 5);
        this.chargement = false;
      },
      error: () => {
        this.chargement = false;
      },
    });
  }
}
