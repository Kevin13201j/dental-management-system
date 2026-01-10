import { Controller, Get, Post, Body } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  // Endpoint REST para registrar usuarios (Req #15)
  @Post('register')
  async register(@Body() body: any) {
    return this.appService.createUser(body);
  }
}
