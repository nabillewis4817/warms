import { ComponentFixture, TestBed } from '@angular/core/testing';

import { JournalGlobal } from './journal-global';

describe('JournalGlobal', () => {
  let component: JournalGlobal;
  let fixture: ComponentFixture<JournalGlobal>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [JournalGlobal],
    }).compileComponents();

    fixture = TestBed.createComponent(JournalGlobal);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
