import { Controller } from '@nestjs/common';
import { EventPattern, Payload } from '@nestjs/microservices';

@Controller()
export class AppController {
  
  // Escuchamos el evento exacto que enviamos desde Auth
  @EventPattern('user_created')
  handleUserCreated(@Payload() data: any) {
    console.log('------------------------------------------------');
    console.log('🔔 ¡NUEVA NOTIFICACIÓN RECIBIDA DE RABBITMQ!');
    console.log(`📧 Simulando envío de correo a: ${data.email}`);
    console.log(`📝 Mensaje: ${data.message}`);
    console.log(`📅 Fecha: ${data.date}`);
    console.log('------------------------------------------------');
  }
}
