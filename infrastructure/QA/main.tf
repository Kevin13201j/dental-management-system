terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# ---------------------------------------------------------
# 1. LA RED (VPC) - Donde vive todo tu sistema
# ---------------------------------------------------------
resource "aws_vpc" "qa_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "dental-qa-vpc"
  }
}

# Puerta para salir a Internet (Internet Gateway)
resource "aws_internet_gateway" "qa_igw" {
  vpc_id = aws_vpc.qa_vpc.id
  tags = { Name = "dental-qa-igw" }
}

# Subred Pública (Aquí vivirá el Bastion)
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.qa_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Importante para que tenga IP pública
  availability_zone       = "us-east-1a"
  tags = { Name = "dental-qa-public-subnet" }
}

# Tabla de Enrutamiento (Para que la subred salga a internet)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.qa_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.qa_igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------------------------------------------------
# 2. SEGURIDAD (Firewall / Security Group)
# ---------------------------------------------------------
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Permitir entrada SSH solo al Bastion"
  vpc_id      = aws_vpc.qa_vpc.id

  # REGLA DE ENTRADA: Solo puerto 22 (SSH) desde cualquier lado (o tu IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # En prod, esto debería ser solo tu IP
  }

  # REGLA DE SALIDA: El bastion puede hablar con todos hacia afuera
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------------------------------------
# 3. LA INSTANCIA (EC2 Bastion Host) - Req #5
# ---------------------------------------------------------
resource "aws_instance" "bastion_host" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 en us-east-1 (Verificar si cambia)
  instance_type = "t2.micro"              # Capa gratuita
  subnet_id     = aws_subnet.public_subnet.id
  
  # Asociamos el firewall que creamos arriba
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  # Llave SSH (Debes tenerla creada en AWS consola o crearla con terraform)
  key_name = "dental-qa-key" 

  tags = {
    Name        = "Dental-QA-Bastion"
    Environment = "QA"
    Role        = "Bastion/JumpBox"
  }
}