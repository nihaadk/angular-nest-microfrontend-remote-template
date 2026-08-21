import { Injectable } from '@angular/core';
import { httpResource } from '@angular/common/http';
import { getRuntimeEnv } from './runtime-env';

export interface Example {
  id: number;
  title: string;
  description: string;
  tags: string[];
  createdAt: string;
}

@Injectable({ providedIn: 'root' })
export class ExampleService {
  /** Reactive resource that loads the example data from the backend API. */
  readonly example = httpResource<Example>(() => `${getRuntimeEnv().beUrl}/api/example`);
}
