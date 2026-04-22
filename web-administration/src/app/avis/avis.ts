import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-avis',
  imports: [CommonModule],
  templateUrl: './avis.html',
  styleUrl: './avis.scss',
})
export class Avis implements OnInit {
  private readonly http = inject(HttpClient);
  avis: any[] = [];

  ngOnInit(): void {
    this.http.get<any[]>('http://127.0.0.1:8000/api/v1/avis/').subscribe({
      next: (items) => (this.avis = items),
    });
  }
}

// #EbaJioloLewis
