import { ComponentFixture, TestBed } from '@angular/core/testing';

import { DossierPatient } from './dossier-patient';

describe('DossierPatient', () => {
  let component: DossierPatient;
  let fixture: ComponentFixture<DossierPatient>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DossierPatient],
    }).compileComponents();

    fixture = TestBed.createComponent(DossierPatient);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
