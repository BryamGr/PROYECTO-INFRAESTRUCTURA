# --- Grupo de Subred de la Base de Datos ---
resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = [for s in values(aws_subnet.private) : s.id]
  tags       = var.tags
}

# --- Security Group para la Base de Datos (Instancia Real) ---
# Esta SG solo permite tráfico desde el PROXY. Nadie más puede hablar con la BD.
resource "aws_security_group" "db" {
  name   = "${var.project_name}-db-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.db_proxy.id] # <-- Solo acepta al Proxy
    description     = "Acceso desde RDS Proxy"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# --- Instancia de Base de Datos RDS ---
resource "aws_db_instance" "db" {
  identifier                 = "${var.project_name}-db"
  db_name                    = var.db_name
  engine                     = var.db_engine
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  username                   = envasados
  password                   = envasados321
  allocated_storage          = 20
  storage_encrypted          = true
  publicly_accessible        = false
  multi_az                   = false
  skip_final_snapshot        = true
  db_subnet_group_name       = aws_db_subnet_group.db.name
  vpc_security_group_ids     = [aws_security_group.db.id]
  deletion_protection        = false
  performance_insights_enabled = false
  tags = var.tags
}

# --- Security Group para el RDS Proxy ---
# Tus ECS Tasks y tu Lambda se conectarán a ESTE security group.
resource "aws_security_group" "db_proxy" {
  name   = "${var.project_name}-db-proxy-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    security_groups = [
      aws_security_group.ecs_tasks.id, # <-- Permite ECS
      aws_security_group.lambda_vpc.id # <-- Permite Lambda
    ]
    description = "Acceso a RDS Proxy desde ECS y Lambda"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# --- Rol IAM para el RDS Proxy ---
# El Proxy necesita este rol para obtener las credenciales de la BD
# (lo hace automáticamente desde Secrets Manager)
resource "aws_iam_role" "rds_proxy" {
  name = "${var.project_name}-rds-proxy-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "rds.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "rds_proxy" {
  name = "${var.project_name}-rds-proxy-policy"
  role = aws_iam_role.rds_proxy.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      Effect   = "Allow",
      Resource = "*" # En producción, deberías limitar esto al ARN del Secret
    }]
  })
}

# --- El Recurso del RDS Proxy ---
resource "aws_db_proxy" "proxy" {
  name                   = "${var.project_name}-proxy"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.db_proxy.id]
  vpc_subnet_ids         = [for s in values(aws_subnet.private) : s.id]

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  ="arn:aws:secretsmanager:us-east-1:481207241117:secret:envasados_secret-ZYBknc"
    # auth_scheme = "NATIVE"
  }
  
  tags = var.tags


}

# --- Target Group del Proxy ---
# Conecta el Proxy a la instancia de BD
resource "aws_db_proxy_target_group" "default" {
  db_proxy_name = aws_db_proxy.proxy.name
  name          = "default"

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }

  db_instance_identifiers = [aws_db_instance.db.id]
}
