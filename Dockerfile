# 1. Imagen base
FROM node:18-alpine

# Instalamos Nest CLI global
RUN npm install -g @nestjs/cli

WORKDIR /usr/src/app

# 3. COPIAMOS TODO EL ESQUELETO DE CONFIGURACIÓN
COPY package*.json ./
COPY tsconfig*.json ./
COPY nest-cli.json ./
COPY turbo.json ./

# Copiamos los package.json de cada microservicio para que npm sepa qué instalar
COPY apps/api-gateway/package.json ./apps/api-gateway/
COPY apps/auth-service/package.json ./apps/auth-service/

# 4. Instalamos las dependencias (Esto instalará todo lo de la raíz y las apps)
RUN npm install

# 5. Copiamos el resto del código
COPY . .

# 6. Variables de entorno
ARG APP_NAME=api-gateway
ENV APP_NAME=${APP_NAME}

# 7. Construimos (Aquí ya no fallará por falta de librerías)
RUN npx turbo run build --filter=${APP_NAME}

# 8. Encendemos el motor (CORREGIDO PARA TURBOREPO)
CMD ["sh", "-c", "node apps/${APP_NAME}/dist/main"]