variable "identifier" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "allowed_cidrs" { type = list(string) }
variable "engine_version" { default = "15.5" }
variable "instance_class" {}
variable "allocated_storage" { default = 50 }
variable "multi_az" { default = false }
variable "database_name" {}
variable "master_username" {}
variable "environment" {}

resource "random_password" "master" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}"
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.identifier}/db/master"
  description = "RDS master credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = 5432
    database = var.database_name
  })
}

resource "aws_db_subnet_group" "this" {
  name       = var.identifier
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "this" {
  name   = "${var.identifier}-rds"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_kms_key" "rds" {
  description             = "RDS encryption for ${var.identifier}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.identifier}-pg15"
  family = "postgres15"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 4
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result

  vpc_security_group_ids = [aws_security_group.this.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az                = var.multi_az
  publicly_accessible     = false
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  performance_insights_enabled = true
  monitoring_interval          = 60
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection      = var.environment == "prod"
  skip_final_snapshot      = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.identifier}-final-${formatdate("YYYYMMDDhhmm", timestamp())}" : null

  apply_immediately = false

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

output "endpoint" { value = aws_db_instance.this.endpoint }
output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
