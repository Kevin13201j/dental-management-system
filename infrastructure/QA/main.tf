# =========================================================================
# QA INFRASTRUCTURE - DENTAL MANAGEMENT SYSTEM
# Author: Kevin
# Description: Red Aislada, Bastion y Microservicios (Corregido)
# =========================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "DentalManagement"
      Environment = "QA"
      ManagedBy   = "Terraform"
    }
  }
}

# 1. VARIABLE (Para que no falle var.ambiente)
variable "ambiente" {
  default = "QA"
}

# 2. VPC
resource "aws_vpc" "qa_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "dental-qa-vpc" }
}

resource "aws_internet_gateway" "qa_igw" {
  vpc_id = aws_vpc.qa_vpc.id
  tags = { Name = "dental-qa-igw" }
}

# 3. SUBREDES (Pública y Privada)

# A. PÚBLICA (Bastion)
resource "aws_subnet" "qa_public_subnet" {
  vpc_id                  = aws_vpc.qa_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "dental-qa-subnet-public" }
}

resource "aws_route_table" "qa_public_rt" {
  vpc_id = aws_vpc.qa_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.qa_igw.id
  }
}

resource "aws_route_table_association" "qa_public_assoc" {
  subnet_id      = aws_subnet.qa_public_subnet.id
  route_table_id = aws_route_table.qa_public_rt.id
}

# B. PRIVADA (Microservicios) - ¡ESTA FALTABA!
resource "aws_subnet" "qa_private_subnet" {
  vpc_id            = aws_vpc.qa_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "dental-qa-subnet-private" }
}

# 4. SEGURIDAD

resource "aws_security_group" "bastion_sg" {
  name   = "dental-qa-bastion-sg"
  vpc_id = aws_vpc.qa_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app_sg" {
  name   = "dental-app-sg-${var.ambiente}"
  vpc_id = aws_vpc.qa_vpc.id # Corregido (antes decia main_vpc)

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.qa_vpc.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. INSTANCIAS

# Buscador de Ubuntu (Uno solo para todos)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Bastion Host
resource "aws_instance" "bastion_host" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.qa_public_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name      = "vockey"
  tags = { Name = "Dental-QA-BastionHost" }
}

# App Server (Microservicios)
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.qa_private_subnet.id # Corregido (ahora sí existe)
  key_name      = "vockey"
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io git curl
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name        = "dental-app-server-${var.ambiente}"
    Environment = var.ambiente
  }
}

# =========================================================================
# 6. BALANCEADOR DE CARGA (ALB) - La Puerta de Entrada Web
# =========================================================================

# A. Security Group del Balanceador (Acepta tráfico web de todo el mundo)
resource "aws_security_group" "alb_sg" {
  name        = "dental-alb-sg-${var.ambiente}"
  description = "Permitir HTTP desde internet"
  vpc_id      = aws_vpc.qa_vpc.id

  ingress {
    description = "HTTP desde cualquier lugar"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# B. El Balanceador (ALB)
resource "aws_lb" "app_alb" {
  name               = "dental-alb-${var.ambiente}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  
  # El ALB necesita estar en subredes públicas (Al menos 2 zonas por regla de AWS, 
  # pero usaremos la misma para este laboratorio académico si solo tenemos una)
  subnets            = [aws_subnet.qa_public_subnet.id, aws_subnet.qa_public_subnet_2.id] 

  tags = {
    Name = "dental-alb-${var.ambiente}"
  }
}

# TRUCO: Como el ALB exige 2 subredes en zonas distintas, creamos una "falsa" rapido
# Solo para cumplir el requisito de AWS. Copia esto antes del ALB:
resource "aws_subnet" "qa_public_subnet_2" {
  vpc_id            = aws_vpc.qa_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b" # Zona Diferente (B)
  tags = { Name = "dental-qa-subnet-public-2" }
}

# C. Target Group del Gateway (Puerto 3000)
resource "aws_lb_target_group" "app_tg" {
  name     = "dental-tg-${var.ambiente}"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.qa_vpc.id # Usamos el nombre exacto de tu código
  
  health_check {
    path                = "/" 
    interval            = 30   # Revisa cada 30 segundos
    timeout             = 10   # Espera 10 segundos la respuesta
    healthy_threshold   = 2    # 2 éxitos para estar "Sano"
    unhealthy_threshold = 5    # 5 fallos para estar "Caído"
  }
}
# Target Group: Auth
resource "aws_lb_target_group" "auth_tg" {
  name     = "dental-auth-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = aws_vpc.qa_vpc.id
  health_check { path = "/" }
}

# Target Group: Appointments
resource "aws_lb_target_group" "appointments_tg" {
  name     = "dental-appointments-tg"
  port     = 3002
  protocol = "HTTP"
  vpc_id   = aws_vpc.qa_vpc.id
  health_check { path = "/" }
}


# D. Listener (El oido del ALB)
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# E. Conectar el Servidor al Grupo
resource "aws_lb_target_group_attachment" "app_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_server.id
  port             = 3000
}

# OUTPUT FINAL: El Link de tu Pagina Web
output "website_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}

# =========================================================================
# 7. NAT GATEWAY (Internet para la Red Privada)
# =========================================================================

# IP Elástica para el NAT
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# El NAT Gateway (Vive en la pública para salir a la calle)
resource "aws_nat_gateway" "qa_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.qa_public_subnet.id

  tags = { Name = "dental-qa-nat" }
}

# Tabla de Rutas Privada (Todo el tráfico de salida va al NAT)
resource "aws_route_table" "qa_private_rt" {
  vpc_id = aws_vpc.qa_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.qa_nat.id
  }

  tags = { Name = "dental-qa-rt-private" }
}

# Asociar la tabla privada a tu subred privada
resource "aws_route_table_association" "qa_private_assoc" {
  subnet_id      = aws_subnet.qa_private_subnet.id
  route_table_id = aws_route_table.qa_private_rt.id
}

# =========================================================================
# 8. CONFIGURACIÓN DE MICROSERVICIOS (Ruteo por Path)
# =========================================================================

# --- A. REGLA PARA AUTH-SERVICE (Puerto 3001) ---
resource "aws_lb_listener_rule" "auth_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_tg.arn
  }

  condition {
    path_pattern {
      values = ["/auth*"]
    }
  }
}

# --- B. REGLA PARA APPOINTMENTS-SERVICE (Puerto 3002) ---
resource "aws_lb_listener_rule" "appointments_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.appointments_tg.arn
  }

  condition {
    path_pattern {
      values = ["/appointments*"]
    }
  }
}