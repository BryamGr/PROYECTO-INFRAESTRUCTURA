variable "project_name" { type = string, description = "Prefijo de recursos" }
variable "aws_region"   { type = string, description = "Región AWS" }

variable "domain_name"    { type = string, description = "Dominio/subdominio para frontend" }
variable "hosted_zone_id" { type = string, description = "Hosted Zone ID de Route53" }

variable "frontend_bucket_name" { type = string }
variable "uploads_bucket_name"  { type = string }

# VPC
variable "vpc_cidr" { type = string, default = "10.20.0.0/16" }
variable "azs" { type = list(string), default = ["us-east-1a","us-east-1b"] }
variable "public_subnet_cidrs"  { type = list(string), default = ["10.20.0.0/24","10.20.1.0/24"] }
variable "private_subnet_cidrs" { type = list(string), default = ["10.20.10.0/24","10.20.11.0/24"] }
variable "enable_nat_gateway"   { type = bool, default = true }

# ECR/ECS
variable "ecr_repo_prefix" { type = string, default = "dashboard" }
variable "inventario_image" { type = string }
variable "reportes_image"   { type = string }
variable "auth_image"       { type = string }

variable "ecs_cpu"    { type = number, default = 256 }
variable "ecs_memory" { type = number, default = 512 }

# Puertos de contenedor (Node apps)
variable "inventario_port" { type = number, default = 3000 }
variable "reportes_port"   { type = number, default = 3001 }
variable "auth_port"       { type = number, default = 3002 }

variable "desired_count_inventario" { type = number, default = 1 }
variable "desired_count_reportes"   { type = number, default = 1 }
variable "desired_count_auth"       { type = number, default = 1 }

# DB (MySQL)
variable "db_engine"         { type = string, default = "mysql" }
variable "db_engine_version" { type = string, default = "8.0" }
variable "db_instance_class" { type = string, default = "db.t4g.micro" }
variable "db_name"           { type = string, default = "inventario" }
variable "db_username"       { type = string, default = "appuser" }
variable "db_password"       { type = string, sensitive = true }

# Otros
variable "waf_enable"     { type = bool, default = true }
variable "api_stage_name" { type = string, default = "prod" }
variable "lambda_zip_path" { type = string, default = "./lambda/notifier.zip" }
variable "jwt_secret"     { type = string, default = "", sensitive = true }

variable "tags" {
  type = map(string)
  default = {}
}
