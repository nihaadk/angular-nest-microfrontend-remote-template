import { Component, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { RouterOutlet } from '@angular/router';
import { TranslatePipe, provideChildTranslateService, provideTranslateLoader } from '@ngx-translate/core';
import { ExampleService } from './core/example.service';
import { getRuntimeEnv } from './core/runtime-env';
import { BackendTranslateLoader } from './core/backend-translate-loader';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, DatePipe, TranslatePipe],
  templateUrl: './app.html',
  // A *child* TranslateService, scoped to this component (and thus this
  // remote, wherever it's embedded): it has its own loader/store (own
  // translations, from this remote's own backend), but its active language
  // is inherited from - and stays in sync with - whichever TranslateService
  // is already above it in the injector tree (e.g. a host shell's root one),
  // via ngx-translate's built-in parent/child mechanism. If there's no
  // parent (running standalone, or no host TranslateService at all), this
  // just behaves like its own independent root.
  providers: [provideChildTranslateService({ loader: provideTranslateLoader(BackendTranslateLoader) })],
})
export class App {
  private readonly exampleService = inject(ExampleService);
  protected readonly example = this.exampleService.example;
  protected readonly beUrl = getRuntimeEnv().beUrl;
}
