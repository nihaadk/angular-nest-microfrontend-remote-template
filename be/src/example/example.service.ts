import { Injectable } from '@nestjs/common';

export interface Example {
  id: number;
  title: string;
  description: string;
  tags: string[];
  createdAt: string;
}

@Injectable()
export class ExampleService {
  getExample(): Example {
    return {
      id: 1,
      title: 'Beispiel-Datensatz',
      description: 'Diese Daten kommen vom NestJS-Backend der Remote-App und werden im Angular-Frontend angezeigt.',
      tags: ['angular', 'nestjs', 'native-federation', 'daisyui'],
      createdAt: new Date().toISOString(),
    };
  }
}
