import { Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt'; // <--- Para crear tokens
import * as bcrypt from 'bcrypt'; // <--- Para encriptar contraseñas
import { User } from './user.entity';

@Injectable()
export class AppService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private jwtService: JwtService, // Inyectamos el servicio de JWT
  ) {}

  // 1. REGISTRO SEGURO (Hash Password)
  async createUser(userData: any) {
    // Generar un "salt" y encriptar la contraseña
    const hashedPassword = await bcrypt.hash(userData.password, 10);
    
    const newUser = this.userRepository.create({
      ...userData,
      password: hashedPassword, // Guardamos la encriptada, no la original
    });
    return this.userRepository.save(newUser);
  }

  // 2. LOGIN (Validar y generar Token)
  async login(credentials: any) {
    // Buscar al usuario por email
    const user = await this.userRepository.findOne({ where: { email: credentials.email } });
    
    if (!user) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    // Comparar la contraseña que envían con la encriptada en DB
    const isMatch = await bcrypt.compare(credentials.password, user.password);
    
    if (!isMatch) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    // Si todo está bien, generamos el JWT (Req #5)
    const payload = { sub: user.id, email: user.email, role: user.role };
    return {
      access_token: this.jwtService.sign(payload),
    };
  }

  getHello(): string {
    return 'Dental System Auth Service is Running!';
  }
}