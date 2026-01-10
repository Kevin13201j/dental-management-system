import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5433,            // OJO: Es el puerto que abrimos en Docker
      username: 'admin',     // Usuario del docker-compose
      password: 'adminpassword', // Contraseña del docker-compose
      database: 'dental_db', // Base de datos del docker-compose
      autoLoadEntities: true,
      synchronize: true,     // Solo para desarrollo (crea tablas automático)
    }),
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}