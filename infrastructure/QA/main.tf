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
  # Perfil configurado en tu AWS CLI (lo veremos luego)
  profile = "default" 
}

# Bucket S3 para guardar el estado de Terraform (Req #13)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "dental-system-qa-state-kevin13201j" # Debe ser único
  
  tags = {
    Environment = "QA"
    Project     = "DentalSystem"
  }
}