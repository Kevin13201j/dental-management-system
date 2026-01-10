import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { User } from './user.entity'; // <--- IMPORTANTE: Importar la entidad

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
    TypeOrmModule.forFeature([User]), // <--- IMPORTANTE: Registrar la tabla aquí
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}