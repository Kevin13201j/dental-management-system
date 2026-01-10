import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt'; // <--- Nuevo
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { User } from './user.entity';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5433,
      username: 'admin',
      password: 'adminpassword',
      database: 'dental_db',
      autoLoadEntities: true,
      synchronize: true,
    }),
    TypeOrmModule.forFeature([User]),
    // Configuración de Seguridad (JWT) - Req #5
    JwtModule.register({
      secret: 'SECRET_KEY_DENTAL_123', // En producción esto va en variables de entorno (.env)
      signOptions: { expiresIn: '1h' }, // El token expira en 1 hora
    }),
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}