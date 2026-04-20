import { TestBed } from '@angular/core/testing';

import { Messagerie } from './messagerie';

describe('Messagerie', () => {
  let service: Messagerie;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(Messagerie);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
