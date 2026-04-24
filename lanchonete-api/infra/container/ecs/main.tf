# ── infra/container/ecs/main.tf ───────────────────────────────────────────────

variable "project_name"        { default = "lanchonete" }
variable "region"              { default = "sa-east-1" }
variable "ecr_image_uri"       {}   # ex: 123456.dkr.ecr.sa-east-1.amazonaws.com/lanchonete-api:latest
variable "vpc_id"              {}
variable "private_subnet_ids"  { type = list(string) }
variable "sg_app_id"           {}
variable "alb_target_group_arn"{}
variable "desired_count"       { default = 2 }
variable "cpu"                 { default = "512" }
variable "memory"              { default = "1024" }

# ── ECR Repository ────────────────────────────────────────────────────────────
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration { scan_on_push = true }

  tags = { Project = var.project_name }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Manter apenas as últimas 10 imagens"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ── ECS Cluster ───────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "app" {
  name = "${var.project_name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "app" {
  cluster_name       = aws_ecs_cluster.app.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ── CloudWatch Log Group ──────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30
}

# ── IAM — Task Execution Role ─────────────────────────────────────────────────
resource "aws_iam_role" "task_exec" {
  name = "${var.project_name}-ecs-task-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_exec_ssm" {
  name = "ssm-secrets"
  role = aws_iam_role.task_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "kms:Decrypt"]
      Resource = ["arn:aws:ssm:${var.region}:*:parameter/lanchonete/*"]
    }]
  })
}

# ── IAM — Task Role (permissões da aplicação) ─────────────────────────────────
resource "aws_iam_role" "task" {
  name = "${var.project_name}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ── ECS Task Definition ───────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_exec.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = "${var.project_name}-api"
    image     = var.ecr_image_uri
    essential = true

    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]

    environment = [
      { name = "NODE_ENV", value = "production" },
      { name = "PORT",     value = "3000" },
      { name = "DB_PORT",  value = "5432" },
      { name = "DB_NAME",  value = "lanchonete" },
      { name = "DB_USER",  value = "lanchonete_user" },
      { name = "REDIS_PORT", value = "6379" },
    ]

    # Segredos via SSM — injetados como env vars
    secrets = [
      { name = "DB_HOST",      valueFrom = "/lanchonete/prod/db_host" },
      { name = "DB_PASSWORD",  valueFrom = "/lanchonete/prod/db_password" },
      { name = "REDIS_HOST",   valueFrom = "/lanchonete/prod/redis_host" },
    ]

    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:3000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    readonlyRootFilesystem = false
    user                   = "1000"  # appuser (non-root)
  }])

  tags = { Project = var.project_name }
}

# ── ECS Service ───────────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name             = "${var.project_name}-api"
  cluster          = aws_ecs_cluster.app.id
  task_definition  = aws_ecs_task_definition.app.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.sg_app_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "${var.project_name}-api"
    container_port   = 3000
  }

  deployment_controller { type = "ECS" }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Aguarda health check antes de considerar o serviço saudável
  health_check_grace_period_seconds = 60

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }

  tags = { Project = var.project_name }
}

# ── Auto Scaling do ECS ───────────────────────────────────────────────────────
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.app.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = "${var.project_name}-ecs-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60.0
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "ecr_repo_url"    { value = aws_ecr_repository.app.repository_url }
output "ecs_cluster_name"{ value = aws_ecs_cluster.app.name }
output "ecs_service_name"{ value = aws_ecs_service.app.name }
