import { TestBed } from '@angular/core/testing';

import { RendezVous } from './rendez-vous';

describe('RendezVous', () => {
  let service: RendezVous;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(RendezVous);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
