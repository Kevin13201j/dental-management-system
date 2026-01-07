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
  profile = "default"
}

# Bucket S3 EXCLUSIVO para Producción (Aislado del de QA)
resource "aws_s3_bucket" "terraform_state_prod" {
  bucket = "dental-system-prod-state-kevin13201j" # Nombre único para PROD
  
  tags = {
    Environment = "PROD"
    Project     = "DentalSystem"
  }
}