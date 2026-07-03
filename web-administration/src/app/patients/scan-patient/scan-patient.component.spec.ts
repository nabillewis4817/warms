import { TestBed } from '@angular/core/testing';
import { ScanPatientComponent } from './scan-patient.component';

describe('ScanPatientComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ScanPatientComponent],
    }).compileComponents();
  });

  it('should create', () => {
    const fixture = TestBed.createComponent(ScanPatientComponent);
    expect(fixture.componentInstance).toBeTruthy();
  });
});
