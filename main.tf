# --- Logs y Cluster (Sin Cambios) ---
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/${var.project_name}/ecs"
  retention_in_days = 14
  tags              = var.tags
}
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = var.tags
}

# --- Security Groups (VPC Link, ALB, ECS) ---
resource "aws_security_group" "vpc_link" {
  name        = "${var.project_name}-vpc-link-sg"
  description = "ENIs de API GW hacia ALB interno"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB interno"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_link.id]
    description     = "Tráfico desde API GW VPC Link"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}
resource "aws_security_group" "ecs_tasks" {
  name   = "${var.project_name}-ecs-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = var.inventario_port
    to_port         = var.inventario_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port       = var.reportes_port
    to_port         = var.reportes_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    from_port       = var.auth_port
    to_port         = var.auth_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# --- ALB Interno y Listeners (Sin Cambios) ---
resource "aws_lb" "internal" {
  name               = "${var.project_name}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in values(aws_subnet.private) : s.id]
  tags               = var.tags
}
resource "aws_lb_target_group" "inventario" {
  name        = "${var.project_name}-tg-inv"
  port        = var.inventario_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check { path = "/health" }
  tags = var.tags
}
resource "aws_lb_target_group" "reportes" {
  name        = "${var.project_name}-tg-rep"
  port        = var.reportes_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check { path = "/health" }
  tags = var.tags
}
resource "aws_lb_target_group" "auth" {
  name        = "${var.project_name}-tg-auth"
  port        = var.auth_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check { path = "/health" }
  tags = var.tags
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inventario.arn
  }
}
resource "aws_lb_listener_rule" "path_auth" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth.arn
  }
  condition {
    path_pattern {
      values = ["/auth*", "/login*"]
    }
  }
}
resource "aws_lb_listener_rule" "path_inv" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inventario.arn
  }
  condition {
    path_pattern {
      values = ["/inventario*"]
    }
  }
}
resource "aws_lb_listener_rule" "path_rep" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reportes.arn
  }
  condition {
    path_pattern {
      values = ["/reportes*"]
    }
  }
}

# --- IAM para ECS (Sin Cambios) ---
resource "aws_iam_role" "ecs_task_exec" {
  name = "${var.project_name}-ecs-exec"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}
resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}
locals {
  log_cfg = {
    logDriver = "awslogs",
    options = {
      awslogs-group         = aws_cloudwatch_log_group.ecs.name,
      awslogs-region        = var.aws_region,
      awslogs-stream-prefix = "svc"
    }
  }
}

# --- Task Definitions (¡MODIFICADAS!) ---
# La variable "DB_HOST" ahora apunta al endpoint del RDS Proxy.
resource "aws_ecs_task_definition" "inventario" {
  family                   = "${var.project_name}-inventario"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name  = "inventario",
    image = var.inventario_image,
    portMappings = [{ containerPort = var.inventario_port, protocol = "tcp" }],
    logConfiguration = local.log_cfg,
    environment = [
      { name = "DB_HOST", value = aws_db_proxy.proxy.endpoint }, # <-- MODIFICADO
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "DB_PORT", value = "3306" },
      { name = "JWT_SECRET", value = var.jwt_secret }
    ]
  }])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  tags = var.tags
}
resource "aws_ecs_task_definition" "reportes" {
  family                   = "${var.project_name}-reportes"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name  = "reportes",
    image = var.reportes_image,
    portMappings = [{ containerPort = var.reportes_port, protocol = "tcp" }],
    logConfiguration = local.log_cfg,
    environment = [
      { name = "DB_HOST", value = aws_db_proxy.proxy.endpoint }, # <-- MODIFICADO
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "DB_PORT", value = "3306" },
      { name = "JWT_SECRET", value = var.jwt_secret }
    ]
  }])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  tags = var.tags
}
resource "aws_ecs_task_definition" "auth" {
  family                   = "${var.project_name}-auth"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name  = "auth",
    image = var.auth_image,
    portMappings = [{ containerPort = var.auth_port, protocol = "tcp" }],
    logConfiguration = local.log_cfg,
    environment = [
      { name = "DB_HOST", value = aws_db_proxy.proxy.endpoint }, # <-- MODIFICADO
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_PASSWORD", value = var.db_password },
      { name = "DB_PORT", value = "3306" },
      { name = "JWT_SECRET", value = var.jwt_secret }
    ]
  }])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  tags = var.tags
}

# --- Servicios ECS (Sin Cambios) ---
resource "aws_ecs_service" "inventario" {
  name            = "${var.project_name}-inventario"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.inventario.arn
  desired_count   = var.desired_count_inventario
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [for s in values(aws_subnet.private) : s.id]
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.inventario.arn
    container_name   = "inventario"
    container_port   = var.inventario_port
  }
  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}
resource "aws_ecs_service" "reportes" {
  name            = "${var.project_name}-reportes"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.reportes.arn
  desired_count   = var.desired_count_reportes
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [for s in values(aws_subnet.private) : s.id]
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.reportes.arn
    container_name   = "reportes"
    container_port   = var.reportes_port
  }
  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}
resource "aws_ecs_service" "auth" {
  name            = "${var.project_name}-auth"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.auth.arn
  desired_count   = var.desired_count_auth
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = [for s in values(aws_subnet.private) : s.id]
    security_groups = [aws_security_group.ecs_tasks.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.auth.arn
    container_name   = "auth"
    container_port   = var.auth_port
  }
  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}

# --- API Gateway HTTP → VPC Link → ALB (Sin Cambios) ---
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  tags          = var.tags
}
resource "aws_apigatewayv2_vpc_link" "link" {
  name               = "${var.project_name}-vpc-link"
  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids         = [for s in values(aws_subnet.private) : s.id]
  tags               = var.tags
}
resource "aws_apigatewayv2_integration" "alb" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "HTTP_PROXY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.link.id
  integration_method     = "ANY"
  integration_uri        = aws_lb_listener.http.arn
  payload_format_version = "1.0"
}
resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = var.api_stage_name
  auto_deploy = true
  tags        = var.tags
}

# --- RECURSOS DE BD MOVIDOS A RDS.TF ---
# (El aws_db_subnet_group, aws_security_group.db y aws_db_instance
# ya no están aquí)

# --- Configuración de Notificaciones (EventBridge, SQS, Lambda) ---
# (MODIFICADO para apuntar al endpoint del PROXY)

resource "aws_sqs_queue" "notificaciones_inventario" {
  name                       = "${var.project_name}-notificaciones-inventario"
  visibility_timeout_seconds = 60
  tags                       = var.tags
}

resource "aws_security_group" "lambda_vpc" {
  name        = "${var.project_name}-lambda-vpc-sg"
  description = "Security group para la Lambda de notificaciones"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = var.tags
}
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "${var.project_name}-lambda-sqs-policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Resource = aws_sqs_queue.notificaciones_inventario.arn
      }
    ]
  })
}
resource "aws_iam_role_policy" "lambda_ses_policy" {
  name = "${var.project_name}-lambda-ses-policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ses:SendEmail", "ses:SendRawEmail"],
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "archive_file" "notifier" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda/notifier.zip"
}

resource "aws_lambda_function" "procesador_notificaciones" {
  function_name    = "${var.project_name}-procesador-notificaciones"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.notifier.output_path
  source_code_hash = data.archive_file.notifier.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30

  environment {
    variables = {
      DB_HOST     = aws_db_proxy.proxy.endpoint # <-- MODIFICADO
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
      DB_NAME     = var.db_name
      ADMIN_EMAIL = "admin@tu-tienda.com"
    }
  }
  vpc_config {
    subnet_ids         = [for s in values(aws_subnet.private) : s.id]
    security_group_ids = [aws_security_group.lambda_vpc.id]
  }

  tags = var.tags
}
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.notificaciones_inventario.arn
  function_name    = aws_lambda_function.procesador_notificaciones.arn
  batch_size       = 1
}

# --- Reglas de EventBridge (Sin Cambios) ---
resource "aws_eventbridge_rule" "alerta_30_dias" {
  name                = "${var.project_name}-alerta-30-dias"
  description         = "Alerta de inventario para 30 días"
  schedule_expression = "cron(0 9 * * ? *)"
  tags                = var.tags
}
resource "aws_eventbridge_rule" "alerta_15_dias" {
  name                = "${var.project_name}-alerta-15-dias"
  description         = "Alerta de inventario para 15 días"
  schedule_expression = "cron(0 9 * * ? *)"
  tags                = var.tags
}
resource "aws_eventbridge_rule" "alerta_7_dias" {
  name                = "${var.project_name}-alerta-7-dias"
  description         = "Alerta de inventario para 7 días"
  schedule_expression = "cron(0 9 * * ? *)"
  tags                = var.tags
}
resource "aws_eventbridge_rule" "alerta_1_dia" {
  name                = "${var.project_name}-alerta-1-dia"
  description         = "Alerta de inventario para 1 día"
  schedule_expression = "cron(0 9 * * ? *)"
  tags                = var.tags
}

# --- Destinos de EventBridge (Sin Cambios) ---
resource "aws_eventbridge_target" "target_sqs_30_dias" {
  rule      = aws_eventbridge_rule.alerta_30_dias.name
  target_id = "sqs-notificacion-30d"
  arn       = aws_sqs_queue.notificaciones_inventario.arn
  input = jsonencode({
    "tipo_alerta" : "30_dias",
    "descripcion" : "Generar reporte de productos a 30 días de caducidad o falta de stock."
  })
}
resource "aws_eventbridge_target" "target_sqs_15_dias" {
  rule      = aws_eventbridge_rule.alerta_15_dias.name
  target_id = "sqs-notificacion-15d"
  arn       = aws_sqs_queue.notificaciones_inventario.arn
  input = jsonencode({
    "tipo_alesta" : "15_dias",
    "descripcion" : "Generar reporte de productos a 15 días de caducidad o falta de stock."
  })
}
resource "aws_eventbridge_target" "target_sqs_7_dias" {
  rule      = aws_eventbridge_rule.alerta_7_dias.name
  target_id = "sqs-notificacion-7d"
  arn       = aws_sqs_queue.notificaciones_inventario.arn
  input = jsonencode({
    "tipo_alerta" : "7_dias",
    "descripcion" : "Generar reporte de productos a 7 días de caducidad o falta de stock."
  })
}
resource "aws_eventbridge_target" "target_sqs_1_dia" {
  rule      = aws_eventbridge_rule.alerta_1_dia.name
  target_id = "sqs-notificacion-1d"
  arn       = aws_sqs_queue.notificaciones_inventario.arn
  input = jsonencode({
    "tipo_alerta" : "1_dia",
    "descripcion" : "Generar reporte de productos a 1 día de caducidad o falta de stock."
  })
}