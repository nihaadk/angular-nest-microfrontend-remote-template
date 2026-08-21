// Loads a local .env file (if present) into process.env - only relevant for
// local dev. On Railway, variables are already injected into the process
// environment, so this is a no-op there.
import 'dotenv/config';

import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Comma-separated list of allowed origins: this remote's own dev server
  // plus the host shell's, since both may call this API directly.
  const corsOrigins = (process.env.CORS_ORIGINS ?? 'http://localhost:4201,http://localhost:4200')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  app.enableCors({ origin: corsOrigins });

  app.setGlobalPrefix('api');
  // Bind explicitly to 0.0.0.0 - on Railway/Alpine, listen(port) without a
  // host can end up IPv6-loopback-only, which the edge proxy can't reach
  // (manifests as a 502 "Application failed to respond").
  await app.listen(process.env.PORT ?? 3001, '0.0.0.0');
}
bootstrap();
