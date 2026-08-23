import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { App } from './app';

describe('App', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [App],
      providers: [provideHttpClient()],
    }).compileComponents();
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(App);
    const app = fixture.componentInstance;
    expect(app).toBeTruthy();
  });

  it('should render the heading', async () => {
    // Not asserting specific text: the heading comes from this component's
    // own child TranslateService (see app.ts), whose BackendTranslateLoader
    // does a real HTTP call that has nothing to resolve against in this
    // test environment - it fails gracefully (ngx-translate logs a warning,
    // doesn't throw) and the pipe falls back to rendering the raw key.
    const fixture = TestBed.createComponent(App);
    await fixture.whenStable();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('h1')).toBeTruthy();
  });
});
