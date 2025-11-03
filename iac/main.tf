# Logs
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/${var.project_name}/ecs"
  retention_in_days = 14
  tags              = var.tags
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
  setting { name = "containerInsights", value = "enabled" }
  tags = var.tags
}

# SGs
resource "aws_security_group" "vpc_link" {
  name        = "${var.project_name}-vpc-link-sg"
  description = "ENIs de API GW hacia ALB interno"
  vpc_id      = aws_vpc.main.id
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
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
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  tags = var.tags
}

resource "aws_security_group" "ecs_tasks" {
  name   = "${var.project_name}-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress { from_port = var.inventario_port, to_port = var.inventario_port, protocol = "tcp", security_groups = [aws_security_group.alb.id] }
  ingress { from_port = var.reportes_port,   to_port = var.reportes_port,   protocol = "tcp", security_groups = [aws_security_group.alb.id] }
  ingress { from_port = var.auth_port,       to_port = var.auth_port,       protocol = "tcp", security_groups = [aws_security_group.alb.id] }

  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  tags = var.tags
}

# ALB interno
resource "aws_lb" "internal" {
  name               = "${var.project_name}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in values(aws_subnet.private) : s.id]
  tags               = var.tags
}

# Target Groups
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
  default_action { type = "forward", target_group_arn = aws_lb_target_group.inventario.arn }
}

resource "aws_lb_listener_rule" "path_auth" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action { type = "forward", target_group_arn = aws_lb_target_group.auth.arn }
  condition { path_pattern { values = ["/auth*","/login*"] } }
}
resource "aws_lb_listener_rule" "path_inv" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20
  action { type = "forward", target_group_arn = aws_lb_target_group.inventario.arn }
  condition { path_pattern { values = ["/inventario*"] } }
}
resource "aws_lb_listener_rule" "path_rep" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30
  action { type = "forward", target_group_arn = aws_lb_target_group.reportes.arn }
  condition { path_pattern { values = ["/reportes*"] } }
}

# IAM para ECS
resource "aws_iam_role" "ecs_task_exec" {
  name = "${var.project_name}-ecs-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect="Allow", Principal={ Service="ecs-tasks.amazonaws.com" }, Action="sts:AssumeRole"}]
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
    Version = "2012-10-17",
    Statement = [{ Effect="Allow", Principal={ Service="ecs-tasks.amazonaws.com" }, Action="sts:AssumeRole"}]
  })
  tags = var.tags
}

# Logs comunes
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

# Task Definitions
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
    portMappings     = [{ containerPort = var.inventario_port, protocol = "tcp" }],
    logConfiguration = local.log_cfg,
    environment = [
      { name="DB_HOST", value = aws_db_instance.db.address },
      { name="DB_NAME", value = var.db_name },
      { name="DB_USER", value = var.db_username },
      { name="DB_PASSWORD", value = var.db_password },
      { name="DB_PORT", value = "3306" },
      { name="JWT_SECRET", value = var.jwt_secret }
    ]
  }])
  runtime_platform { operating_system_family = "LINUX", cpu_architecture = "X86_64" }
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
    portMappings     = [{ containerPort = var.reportes_port, protocol = "tcp" }],
    logConfiguration = local.log_cfg,
    environment = [
      { name="DB_HOST", value = aws_db_instance.db.address },
      { name="DB_NAME", value = var.db_name },
      { name="DB_USER", value = var.db_username },
      { name="DB_PASSWORD", value = var.db_password },
      { name="DB_PORT", value = "3306" },
      { name="JWT_SECRET", value = var.jwt_secret }
    ]
  }])
  runtime_platform { operating_system_family = "LINUX", cpu_architecture = "X86_64" }
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
    portMappings     = [{ containerPort = var.auth_port, protocol = "tcp" }],
    logConfiguration = local.log_cfg,
    environment = [
      { name="DB_HOST", value = aws_db_instance.db.address },
      { name="DB_NAME", value = var.db_name },
      { name="DB_USER", value = var.db_username },
      { name="DB_PASSWORD", value = var.db_password },
      { name="DB_PORT", value = "3306" },
      { name="JWT_SECRET", value = var.jwt_secret }
    ]
  }])
  runtime_platform { operating_system_family = "LINUX", cpu_architecture = "X86_64" }
  tags = var.tags
}

# Servicios ECS
resource "aws_ecs_service" "inventario" {
  name            = "${var.project_name}-inventario"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.inventario.arn
  desired_count   = var.desired_count_inventario
  launch_type     = "FARGATE"
  network_configuration { subnets = [for s in values(aws_subnet.private) : s.id], security_groups = [aws_security_group.ecs_tasks.id] }
  load_balancer { target_group_arn = aws_lb_target_group.inventario.arn, container_name = "inventario", container_port = var.inventario_port }
  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}

resource "aws_ecs_service" "reportes" {
  name            = "${var.project_name}-reportes"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.reportes.arn
  desired_count   = var.desired_count_reportes
  launch_type     = "FARGATE"
  network_configuration { subnets = [for s in values(aws_subnet.private) : s.id], security_groups = [aws_security_group.ecs_tasks.id] }
  load_balancer { target_group_arn = aws_lb_target_group.reportes.arn, container_name = "reportes", container_port = var.reportes_port }
  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}

resource "aws_ecs_service" "auth" {
  name            = "${var.project_name}-auth"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.auth.arn
  desired_count   = var.desired_count_auth
  launch_type     = "FARGATE"
  network_configuration { subnets = [for s in values(aws_subnet.private) : s.id], security_groups = [aws_security_group.ecs_tasks.id] }
  load_balancer { target_group_arn = aws_lb_target_group.auth.arn, container_name = "auth", container_port = var.auth_port }
  depends_on = [aws_lb_listener.http]
  tags       = var.tags
}

# API Gateway HTTP → VPC Link → ALB
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

# RDS MySQL
resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = [for s in values(aws_subnet.private) : s.id]
  tags       = var.tags
}
resource "aws_security_group" "db" {
  name   = "${var.project_name}-db-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
    description     = "ECS tasks"
  }
  egress { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
  tags = var.tags
}
resource "aws_db_instance" "db" {
  identifier                   = "${var.project_name}-db"
  db_name                      = var.db_name
  engine                       = var.db_engine
  engine_version               = var.db_engine_version
  instance_class               = var.db_instance_class
  username                     = var.db_username
  password                     = var.db_password
  allocated_storage            = 20
  storage_encrypted            = true
  publicly_accessible          = false
  multi_az                     = false
  skip_final_snapshot          = true
  db_subnet_group_name         = aws_db_subnet_group.db.name
  vpc_security_group_ids       = [aws_security_group.db.id]
  deletion_protection          = false
  performance_insights_enabled = false
  tags = var.tags
}

# (Opcional) Demo: SNS/SQS/Lambda/EventBridge
resource "aws_sns_topic" "alerts" { name = "${var.project_name}-alerts"; tags = var.tags }

resource "aws_sqs_queue" "events" {
  name                       = "${var.project_name}-events"
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 30
  tags = var.tags
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version="2012-10-17",
    Statement=[{Effect="Allow",Principal={Service="lambda.amazonaws.com"},Action="sts:AssumeRole"}]
  })
  tags = var.tags
}
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_lambda_function" "notifier" {
  function_name = "${var.project_name}-notifier"
  role          = aws_iam_role.lambda.arn
  filename      = var.lambda_zip_path
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10
  environment { variables = { TOPIC_ARN = aws_sns_topic.alerts.arn } }
  tags = var.tags
}
resource "aws_cloudwatch_event_rule" "hourly" {
  name                = "${var.project_name}-hourly"
  schedule_expression = "rate(1 hour)"
  tags                = var.tags
}
resource "aws_cloudwatch_event_target" "to_lambda" {
  rule      = aws_cloudwatch_event_rule.hourly.name
  target_id = "lambda"
  arn       = aws_lambda_function.notifier.arn
}
resource "aws_cloudwatch_event_target" "to_sqs" {
  rule      = aws_cloudwatch_event_rule.hourly.name
  target_id = "queue"
  arn       = aws_sqs_queue.events.arn
}
resource "aws_lambda_permission" "events" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.hourly.arn
}
