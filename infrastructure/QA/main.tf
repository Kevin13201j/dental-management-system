# =========================================================================
# QA INFRASTRUCTURE - DENTAL MANAGEMENT SYSTEM
# Author: Kevin
# Description: Isolated Network (VPC), Public Subnet, and Bastion Host.
# =========================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider Configuration
# Credentials will be loaded from environment variables (AWS Academy)
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

# =========================================================================
# 1. VPC (Virtual Private Cloud) - The Isolated Network
# =========================================================================
resource "aws_vpc" "qa_vpc" {
  cidr_block           = "10.0.0.0/16" # Exclusive IP range for QA
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dental-qa-vpc"
  }
}

# Internet Gateway (IGW)
# Allows the VPC to communicate with the outside world
resource "aws_internet_gateway" "qa_igw" {
  vpc_id = aws_vpc.qa_vpc.id

  tags = {
    Name = "dental-qa-igw"
  }
}

# =========================================================================
# 2. PUBLIC SUBNET (DMZ Zone)
# =========================================================================
# This subnet will host the Bastion Host and Load Balancers.
resource "aws_subnet" "qa_public_subnet" {
  vpc_id                  = aws_vpc.qa_vpc.id
  cidr_block              = "10.0.1.0/24" # Sub-range for public resources
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Automatically assign public IP

  tags = {
    Name = "dental-qa-subnet-public"
  }
}

# Route Table for Public Access
resource "aws_route_table" "qa_public_rt" {
  vpc_id = aws_vpc.qa_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Route all external traffic to IGW
    gateway_id = aws_internet_gateway.qa_igw.id
  }

  tags = {
    Name = "dental-qa-rt-public"
  }
}

# Route Table Association
resource "aws_route_table_association" "qa_public_assoc" {
  subnet_id      = aws_subnet.qa_public_subnet.id
  route_table_id = aws_route_table.qa_public_rt.id
}

# =========================================================================
# 3. SECURITY (Firewalls / Security Groups)
# =========================================================================

# Security Group for BASTION HOST
# Strict Rule: Only allow SSH (Port 22)
resource "aws_security_group" "bastion_sg" {
  name        = "dental-qa-bastion-sg"
  description = "Security Group for Bastion Host"
  vpc_id      = aws_vpc.qa_vpc.id

  # INGRESS: Allow SSH traffic
  ingress {
    description = "SSH from Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # In production, restrict to admin IP
  }

  # EGRESS: Allow all outbound traffic (for updates)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dental-qa-bastion-sg"
  }
}

# =========================================================================
# 4. EC2 INSTANCE (Bastion Host)
# =========================================================================

# Data Source: Get the latest Ubuntu 22.04 AMI dynamically
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu Creator)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# The Bastion Server
resource "aws_instance" "bastion_host" {
  ami           = data.aws_ami.ubuntu.id # Uses the latest image found above
  instance_type = "t2.micro"             # Free tier eligible
  subnet_id     = aws_subnet.qa_public_subnet.id
  
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = "vockey" # AWS Academy default key

  tags = {
    Name = "Dental-QA-BastionHost"
    Role = "Bastion/JumpBox"
  }
}

# Output: Display the Public IP after creation
output "bastion_public_ip" {
  value       = aws_instance.bastion_host.public_ip
  description = "Public IP of the Bastion Host for SSH access"
}