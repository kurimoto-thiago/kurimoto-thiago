# ── infra/modules/elasticache/main.tf ────────────────────────────────────────

variable "project_name"       { default = "lanchonete" }
variable "vpc_id"             {}
variable "private_subnet_ids" { type = list(string) }
variable "sg_app_id"          {}
variable "node_type"          { default = "cache.t3.micro" }
variable "num_cache_clusters" { default = 2 }   # primary + 1 replica
variable "redis_version"      { default = "7.1" }

# ── Subnet Group ──────────────────────────────────────────────────────────────
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.project_name}-redis-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = { Project = var.project_name }
}

# ── Security Group exclusivo para o Redis ────────────────────────────────────
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-sg-redis"
  description = "Permite acesso ao Redis apenas da app"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis da app"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.sg_app_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-redis", Project = var.project_name }
}

# ── Parameter Group ───────────────────────────────────────────────────────────
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.project_name}-redis7"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"   # habilita keyspace notifications (expiração)
  }
}

# ── Replication Group (Primary + Replica) ─────────────────────────────────────
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.project_name}-redis"
  description          = "Redis para cache e Pub/Sub da lanchonete"

  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  engine_version       = var.redis_version
  parameter_group_name = aws_elasticache_parameter_group.this.name

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = false   # dentro da VPC — sem TLS para simplicidade
  automatic_failover_enabled = var.num_cache_clusters > 1

  snapshot_retention_limit = 1
  snapshot_window          = "04:00-05:00"
  maintenance_window       = "Mon:05:00-Mon:06:00"

  apply_immediately = false

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = { Project = var.project_name }
}

resource "aws_cloudwatch_log_group" "redis" {
  name              = "/elasticache/${var.project_name}"
  retention_in_days = 14
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "primary_endpoint"    { value = aws_elasticache_replication_group.this.primary_endpoint_address }
output "reader_endpoint"     { value = aws_elasticache_replication_group.this.reader_endpoint_address }
output "redis_port"          { value = 6379 }
