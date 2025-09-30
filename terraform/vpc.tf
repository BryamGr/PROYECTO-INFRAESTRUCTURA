Configuración de la VPC principal
provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "dashboard_inventario" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "dashboard-inventario-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.dashboard_inventario.id
  
  tags = {
    Name = "igw-dashboard-inventario"
  }
}

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.dashboard_inventario.id
}

output "vpc_cidr_block" {
  description = "CIDR block de la VPC"
  value       = aws_vpc.dashboard_inventario.cidr_block
}
