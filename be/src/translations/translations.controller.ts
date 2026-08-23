import { Controller, Get, Param } from '@nestjs/common';
import type { TranslationDictionary } from './translations.service';
import { TranslationsService } from './translations.service';

@Controller('translations')
export class TranslationsController {
  constructor(private readonly translationsService: TranslationsService) {}

  @Get(':lang')
  getTranslations(@Param('lang') lang: string): TranslationDictionary {
    return this.translationsService.getTranslations(lang);
  }
}
