import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ExampleModule } from './example/example.module';
import { TranslationsModule } from './translations/translations.module';

@Module({
  imports: [ExampleModule, TranslationsModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
