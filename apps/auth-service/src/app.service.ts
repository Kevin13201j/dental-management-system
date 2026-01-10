import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';

@Injectable()
export class AppService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  // SOLUCIÓN: Quitamos ": Promise<User>" para que TypeScript detecte el tipo automáticamente
  async createUser(userData: any) {
    const newUser = this.userRepository.create(userData);
    return this.userRepository.save(newUser);
  }

  getHello(): string {
    return 'Dental System Auth Service is Running!';
  }
}