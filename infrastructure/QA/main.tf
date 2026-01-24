# =========================================================================
# QA INFRASTRUCTURE - DENTAL MANAGEMENT SYSTEM
# Author: Kevin
# Description: Red Aislada, Bastion y Microservicios (Versión Final)
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

# 1. VARIABLE
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

# 3. SUBREDES
resource "aws_subnet" "qa_public_subnet" {
  vpc_id                  = aws_vpc.qa_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "dental-qa-subnet-public" }
}

resource "aws_subnet" "qa_public_subnet_2" {
  vpc_id            = aws_vpc.qa_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "dental-qa-subnet-public-2" }
}

resource "aws_subnet" "qa_private_subnet" {
  vpc_id            = aws_vpc.qa_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "dental-qa-subnet-private" }
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

resource "aws_security_group" "alb_sg" {
  name        = "dental-alb-sg-${var.ambiente}"
  vpc_id      = aws_vpc.qa_vpc.id

  ingress {
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

resource "aws_security_group" "app_sg" {
  name   = "dental-app-sg-${var.ambiente}"
  vpc_id = aws_vpc.qa_vpc.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. INSTANCIAS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "bastion_host" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.qa_public_subnet.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = "vockey"
  tags                   = { Name = "Dental-QA-BastionHost" }
}

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.qa_private_subnet.id
  key_name               = "vockey"
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

# 6. BALANCEADOR DE CARGA (ALB)
resource "aws_lb" "app_alb" {
  name               = "dental-alb-${var.ambiente}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.qa_public_subnet.id, aws_subnet.qa_public_subnet_2.id]
}

resource "aws_lb_target_group" "app_tg" {
  name     = "dental-tg-${var.ambiente}"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.qa_vpc.id
  health_check { path = "/" }
}

resource "aws_lb_target_group" "auth_tg" {
  name     = "dental-auth-tg"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = aws_vpc.qa_vpc.id
  health_check { path = "/" }
}

resource "aws_lb_target_group" "appointments_tg" {
  name     = "dental-appointments-tg"
  port     = 3002
  protocol = "HTTP"
  vpc_id   = aws_vpc.qa_vpc.id
  health_check { path = "/" }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# 7. NAT GATEWAY
resource "aws_eip" "nat_eip" { domain = "vpc" }

resource "aws_nat_gateway" "qa_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.qa_public_subnet.id
  tags          = { Name = "dental-qa-nat" }
}

resource "aws_route_table" "qa_private_rt" {
  vpc_id = aws_vpc.qa_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.qa_nat.id
  }
}

resource "aws_route_table_association" "qa_private_assoc" {
  subnet_id      = aws_subnet.qa_private_subnet.id
  route_table_id = aws_route_table.qa_private_rt.id
}

# 8. REGLAS DE MICROSERVICIOS
resource "aws_lb_listener_rule" "auth_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_tg.arn
  }
  condition { path_pattern { values = ["/auth*"] } }
}

resource "aws_lb_listener_rule" "appointments_rule" {
  listener_arn = aws_lb_listener.front_end.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.appointments_tg.arn
  }
  condition { path_pattern { values = ["/appointments*"] } }
}

# =========================================================================
# 9. CONEXIONES (ATTACHMENTS) - ¡AQUÍ ESTÁ LO QUE SOLICITASTE!
# =========================================================================

# Conexión Directa por IP de QA (Validación solicitada)
resource "aws_lb_target_group_attachment" "dental_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = "44.222.148.76" 
  port             = 80
}

# Conexión del App Server a los microservicios
resource "aws_lb_target_group_attachment" "app_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_server.id
  port             = 3000
}

resource "aws_lb_target_group_attachment" "auth_attachment" {
  target_group_arn = aws_lb_target_group.auth_tg.arn
  target_id        = aws_instance.app_server.id
  port             = 3001
}

resource "aws_lb_target_group_attachment" "appointments_attachment" {
  target_group_arn = aws_lb_target_group.appointments_tg.arn
  target_id        = aws_instance.app_server.id
  port             = 3002
}

output "website_url" {
  value = "http://${aws_lb.app_alb.dns_name}"
}