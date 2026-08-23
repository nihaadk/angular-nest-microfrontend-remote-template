import { Component, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { RouterOutlet } from '@angular/router';
import { ExampleService } from './core/example.service';
import { getRuntimeEnv } from './core/runtime-env';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, DatePipe],
  templateUrl: './app.html',
})
export class App {
  private readonly exampleService = inject(ExampleService);
  protected readonly example = this.exampleService.example;
  protected readonly beUrl = getRuntimeEnv().beUrl;
}
