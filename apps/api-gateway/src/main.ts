import { NestFactory } from '@nestjs/core';
import { ApiGatewayModule } from './api-gateway.module'; 

async function bootstrap() {
  // Usamos ApiGatewayModule en lugar de AppModule
  const app = await NestFactory.create(ApiGatewayModule);
  
  // Habilitar CORS
  app.enableCors();
  
  // El Gateway escucha en el puerto 3000
  await app.listen(3000);
  console.log('🚀 API Gateway corriendo en: http://localhost:3000');
}
bootstrap();
