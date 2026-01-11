import { NestFactory } from '@nestjs/core';
import { Transport, MicroserviceOptions } from '@nestjs/microservices';
import { AppModule } from './app.module';

async function bootstrap() {
  // En lugar de HTTP, usamos Microservice con RabbitMQ
  const app = await NestFactory.createMicroservice<MicroserviceOptions>(AppModule, {
    transport: Transport.RMQ,
    options: {
      urls: ['amqp://admin:adminpassword@localhost:5672'], // Conexión a tu RabbitMQ local
      queue: 'notifications_queue', // La misma cola donde Auth dejó el mensaje
      queueOptions: {
        durable: false
      },
    },
  });

  await app.listen();
  console.log('📧 Notifications Service está escuchando eventos de RabbitMQ...');
}
bootstrap();
