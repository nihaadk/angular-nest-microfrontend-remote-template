import { Component, inject } from '@angular/core';
import { DatePipe } from '@angular/common';
import { RouterOutlet } from '@angular/router';
import { ExampleService } from './core/example.service';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, DatePipe],
  templateUrl: './app.html',
})
export class App {
  private readonly exampleService = inject(ExampleService);
  protected readonly example = this.exampleService.example;
}
