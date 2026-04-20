import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ListePatients } from './liste-patients';

describe('ListePatients', () => {
  let component: ListePatients;
  let fixture: ComponentFixture<ListePatients>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ListePatients],
    }).compileComponents();

    fixture = TestBed.createComponent(ListePatients);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
