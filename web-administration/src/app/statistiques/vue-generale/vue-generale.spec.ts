import { ComponentFixture, TestBed } from '@angular/core/testing';

import { VueGenerale } from './vue-generale';

describe('VueGenerale', () => {
  let component: VueGenerale;
  let fixture: ComponentFixture<VueGenerale>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [VueGenerale],
    }).compileComponents();

    fixture = TestBed.createComponent(VueGenerale);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
