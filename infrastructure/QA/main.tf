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