# 1. Usamos una imagen ligera de Node.js como base
FROM node:18-alpine

# --- ADICIÓN NECESARIA: Instalamos el CLI de Nest globalmente ---
RUN npm install -g @nestjs/cli

# 2. Creamos la carpeta de trabajo dentro del contenedor
WORKDIR /usr/src/app

# 3. Copiamos los archivos de configuración primero (para aprovechar el caché)
COPY package*.json ./
COPY tsconfig*.json ./
COPY nest-cli.json ./

# --- ADICIÓN NECESARIA: Copiamos el archivo de configuración de Turbo ---
COPY turbo.json ./

# 4. Instalamos las dependencias
RUN npm install

# 5. Copiamos todo el código fuente del proyecto
COPY . .

# 6. Esta variable decidirá qué microservicio encender (por defecto: api-gateway)
ARG APP_NAME=api-gateway
ENV APP_NAME=${APP_NAME}

# 7. Construimos la aplicación específica
RUN npx turbo run build --filter=${APP_NAME}

# 8. Encendemos el motor
CMD node dist/apps/${APP_NAME}/main