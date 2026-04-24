# ── infra/modules/rds/main.tf ─────────────────────────────────────────────────

variable "project_name"       { default = "lanchonete" }
variable "region"             { default = "sa-east-1" }
variable "vpc_id"             {}
variable "private_subnet_ids" { type = list(string) }
variable "sg_app_id"          {}
variable "db_instance_class"  { default = "db.t3.medium" }
variable "db_name"            { default = "lanchonete" }
variable "db_user"            { default = "lanchonete_user" }
variable "db_password_secret" { sensitive = true }
variable "multi_az"           { default = true }
variable "deletion_protection"{ default = true }

# ── Subnet Group ──────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = { Project = var.project_name }
}

# ── Security Group exclusivo para o RDS ───────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "Permite acesso ao PostgreSQL apenas da app"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL da app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.sg_app_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-rds", Project = var.project_name }
}

# ── Parameter Group — PostgreSQL 16 tuning ───────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name   = "${var.project_name}-pg16"
  family = "postgres16"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"   # loga queries > 1s
  }
  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "max_connections"
    value = "200"
  }

  tags = { Project = var.project_name }
}

# ── RDS PostgreSQL ────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "16.2"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  max_allocated_storage = 100   # autoscaling de storage até 100 GB
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password_secret

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az               = var.multi_az
  publicly_accessible    = false
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = { Project = var.project_name }

  lifecycle {
    prevent_destroy       = false
    ignore_changes        = [password]
  }
}

# ── IAM Role para Enhanced Monitoring ────────────────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ── Read Replica (opcional — produção) ───────────────────────────────────────
resource "aws_db_instance" "replica" {
  count = var.multi_az ? 1 : 0

  identifier          = "${var.project_name}-postgres-replica"
  replicate_source_db = aws_db_instance.this.identifier
  instance_class      = var.db_instance_class
  storage_encrypted   = true
  publicly_accessible = false
  skip_final_snapshot = true

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = { Project = var.project_name, Role = "replica" }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "db_endpoint"         { value = aws_db_instance.this.endpoint }
output "db_host"             { value = aws_db_instance.this.address }
output "db_port"             { value = aws_db_instance.this.port }
output "db_name"             { value = aws_db_instance.this.db_name }
output "replica_endpoint"    {
  value = var.multi_az ? aws_db_instance.replica[0].endpoint : null
}
