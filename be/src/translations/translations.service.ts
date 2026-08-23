import { Injectable, Logger } from '@nestjs/common';
import { readFileSync } from 'fs';
import { join } from 'path';

export const SUPPORTED_LANGUAGES = ['en', 'de', 'bs'] as const;
export type SupportedLanguage = (typeof SUPPORTED_LANGUAGES)[number];
const DEFAULT_LANGUAGE: SupportedLanguage = 'en';

/** Nested key -> string dictionary, as expected by ngx-translate. */
export type TranslationDictionary = Record<string, unknown>;

@Injectable()
export class TranslationsService {
  private readonly logger = new Logger(TranslationsService.name);
  private readonly cache = new Map<SupportedLanguage, TranslationDictionary>();

  /**
   * Returns the translation dictionary for a language, falling back to the
   * default language for anything unsupported. Keeping translations here
   * (rather than shipped as static assets in fe/) means new keys or
   * languages ship without rebuilding/redeploying this remote's frontend.
   */
  getTranslations(lang: string): TranslationDictionary {
    const resolved = this.isSupported(lang) ? lang : DEFAULT_LANGUAGE;
    return this.load(resolved);
  }

  private load(lang: SupportedLanguage): TranslationDictionary {
    const cached = this.cache.get(lang);
    if (cached) {
      return cached;
    }

    const filePath = join(__dirname, 'i18n', `${lang}.json`);
    try {
      const dictionary = JSON.parse(readFileSync(filePath, 'utf-8')) as TranslationDictionary;
      this.cache.set(lang, dictionary);
      return dictionary;
    } catch (error) {
      this.logger.error(`Could not read translations for '${lang}' at ${filePath}`, error as Error);
      return {};
    }
  }

  private isSupported(lang: string): lang is SupportedLanguage {
    return (SUPPORTED_LANGUAGES as readonly string[]).includes(lang);
  }
}
