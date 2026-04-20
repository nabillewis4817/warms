import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ListeConversations } from './liste-conversations';

describe('ListeConversations', () => {
  let component: ListeConversations;
  let fixture: ComponentFixture<ListeConversations>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ListeConversations],
    }).compileComponents();

    fixture = TestBed.createComponent(ListeConversations);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
