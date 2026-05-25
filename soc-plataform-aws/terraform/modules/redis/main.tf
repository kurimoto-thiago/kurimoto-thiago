variable "cluster_id" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "allowed_cidrs" { type = list(string) }
variable "node_type" { default = "cache.t4g.micro" }
variable "num_cache_nodes" { default = 1 }
variable "environment" {}

resource "aws_security_group" "this" {
  name   = "${var.cluster_id}-redis"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }
}

resource "aws_elasticache_subnet_group" "this" {
  name       = var.cluster_id
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = var.cluster_id
  description                = "SOC Platform Redis ${var.environment}"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = var.node_type
  num_cache_clusters         = var.num_cache_nodes
  parameter_group_name       = "default.redis7"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.this.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled           = var.num_cache_nodes > 1
  snapshot_retention_limit   = var.environment == "prod" ? 7 : 1
  apply_immediately          = false
}

output "endpoint" { value = aws_elasticache_replication_group.this.primary_endpoint_address }
