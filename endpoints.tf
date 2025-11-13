# --- Security Group para los VPC Endpoints ---
# Permite tráfico HTTPS desde tus subnets privadas
resource "aws_security_group" "vpc_endpoints" {
  name   = "${var.project_name}-vpc-endpoints-sg"
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# --- VPC Endpoint de tipo Gateway para S3 ---
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id] # Se asocia a la tabla de rutas privada
  tags = var.tags
}

# --- VPC Endpoints de tipo Interface (necesitan el SG) ---
locals {
  # Lista de servicios que usarán Endpoints de tipo Interface
  interface_endpoints = {
    "sqs"            : "com.amazonaws.${var.aws_region}.sqs",
    "ses"            : "com.amazonaws.${var.aws_region}.email-ses",
    "ecr_api"        : "com.amazonaws.${var.aws_region}.ecr.api",
    "ecr_dkr"        : "com.amazonaws.${var.aws_region}.ecr.dkr",
    "logs"           : "com.amazonaws.${var.aws_region}.logs",
    "secretsmanager" : "com.amazonaws.${var.aws_region}.secretsmanager"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.main.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  
  subnet_ids = [for s in values(aws_subnet.private) : s.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]
  
  tags = merge(var.tags, { Name = "${var.project_name}-endpoint-${each.key}"})
}