import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Configuración de Swagger (Documentación - Req #21)
  const config = new DocumentBuilder()
    .setTitle('Dental System Auth API')
    .setDescription('Microservicio de Autenticación y Usuarios')
    .setVersion('1.0')
    .addTag('Auth')
    .build();
    
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document); // La docs estará en /api/docs

  // En apps/auth-service/src/main.ts
  await app.listen(3001); 
  console.log('Auth Service is running on: http://localhost:3001');
}
bootstrap();