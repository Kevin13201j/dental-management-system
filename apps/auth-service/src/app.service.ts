import { Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { ClientProxy } from '@nestjs/microservices';
import { User } from './user.entity';

@Injectable()
export class AppService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private jwtService: JwtService,
    // Inyectamos el servicio de RabbitMQ (Req #16)
    @Inject('NOTIFICATIONS_SERVICE') private client: ClientProxy, 
  ) {}

  // 1. REGISTRO SEGURO + EVENTO
  async createUser(userData: any) {
    const hashedPassword = await bcrypt.hash(userData.password, 10);
    
    const newUser = this.userRepository.create({
      ...userData,
      password: hashedPassword,
    });
    
    // CORRECCIÓN: Agregamos ": any" para que TypeScript no marque error
    const savedUser: any = await this.userRepository.save(newUser);

    // Enviar evento a RabbitMQ
    this.client.emit('user_created', {
      email: savedUser.email,
      message: 'Bienvenido al Dental System',
      date: new Date(),
    });

    return savedUser;
  }

  // 2. LOGIN (Este se queda igual, funcionando perfecto)
  async login(credentials: any) {
    const user = await this.userRepository.findOne({ where: { email: credentials.email } });
    
    if (!user) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const isMatch = await bcrypt.compare(credentials.password, user.password);
    
    if (!isMatch) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const payload = { sub: user.id, email: user.email, role: user.role };
    return {
      access_token: this.jwtService.sign(payload),
    };
  }

  getHello(): string {
    return 'Dental System Auth Service is Running!';
  }
}