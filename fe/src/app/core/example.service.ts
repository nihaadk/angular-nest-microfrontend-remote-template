import { Injectable } from '@angular/core';
import { httpResource } from '@angular/common/http';

export interface Example {
  id: number;
  title: string;
  description: string;
  tags: string[];
  createdAt: string;
}

const API_URL = 'http://localhost:3001/api/example';

@Injectable({ providedIn: 'root' })
export class ExampleService {
  /** Reactive resource that loads the example data from the backend API. */
  readonly example = httpResource<Example>(() => API_URL);
}
