import { ComponentFixture, TestBed } from '@angular/core/testing';

import { NouveauPatient } from './nouveau-patient';

describe('NouveauPatient', () => {
  let component: NouveauPatient;
  let fixture: ComponentFixture<NouveauPatient>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [NouveauPatient],
    }).compileComponents();

    fixture = TestBed.createComponent(NouveauPatient);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
