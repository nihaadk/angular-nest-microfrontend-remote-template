import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import type { TranslateLoader, TranslationObject } from '@ngx-translate/core';
import { getRuntimeEnv } from './runtime-env';

/**
 * Fetches this remote's own translations from its own backend (be/src/
 * translations) - not from whatever host shell it happens to be embedded
 * in. Used as a *child* TranslateService's loader (see app.ts), so this
 * remote's translation values stay independent of the host's, while the
 * active language itself is still inherited from the host.
 */
@Injectable({ providedIn: 'root' })
export class BackendTranslateLoader implements TranslateLoader {
  private readonly http = inject(HttpClient);

  getTranslation(lang: string): Observable<TranslationObject> {
    return this.http.get<TranslationObject>(`${getRuntimeEnv().beUrl}/api/translations/${lang}`);
  }
}
