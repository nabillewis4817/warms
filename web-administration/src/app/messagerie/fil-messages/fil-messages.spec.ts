import { ComponentFixture, TestBed } from '@angular/core/testing';

import { FilMessages } from './fil-messages';

describe('FilMessages', () => {
  let component: FilMessages;
  let fixture: ComponentFixture<FilMessages>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FilMessages],
    }).compileComponents();

    fixture = TestBed.createComponent(FilMessages);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
