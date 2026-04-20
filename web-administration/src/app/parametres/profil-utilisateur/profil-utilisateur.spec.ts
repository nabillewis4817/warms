import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ProfilUtilisateur } from './profil-utilisateur';

describe('ProfilUtilisateur', () => {
  let component: ProfilUtilisateur;
  let fixture: ComponentFixture<ProfilUtilisateur>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ProfilUtilisateur],
    }).compileComponents();

    fixture = TestBed.createComponent(ProfilUtilisateur);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
