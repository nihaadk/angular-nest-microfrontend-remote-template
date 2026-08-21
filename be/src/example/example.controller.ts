import { Controller, Get } from '@nestjs/common';
import type { Example } from './example.service';
import { ExampleService } from './example.service';

@Controller('example')
export class ExampleController {
  constructor(private readonly exampleService: ExampleService) {}

  @Get()
  getExample(): Example {
    return this.exampleService.getExample();
  }
}
