import { TestBed } from '@angular/core/testing';

import { Journaux } from './journaux';

describe('Journaux', () => {
  let service: Journaux;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(Journaux);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
