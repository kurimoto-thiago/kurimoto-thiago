# ── infra/main.tf — Root module ───────────────────────────────────────────────
# Orquestra VPC + RDS + ElastiCache
# Usado pelos 3 targets (EC2, Lambda, ECS)

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  # Backend S3 — descomente e ajuste
  # backend "s3" {
  #   bucket = "lanchonete-terraform-state"
  #   key    = "infra/terraform.tfstate"
  #   region = "sa-east-1"
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = var.project_name, ManagedBy = "Terraform" }
  }
}

# ── Variáveis ─────────────────────────────────────────────────────────────────
variable "project_name"      { default = "lanchonete" }
variable "region"            { default = "sa-east-1" }
variable "db_password"       { sensitive = true }
variable "db_instance_class" { default = "db.t3.medium" }
variable "redis_node_type"   { default = "cache.t3.micro" }

# ── Módulos ───────────────────────────────────────────────────────────────────
module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}

module "rds" {
  source             = "./modules/rds"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_app_id          = module.vpc.sg_app_id
  db_instance_class  = var.db_instance_class
  db_password_secret = var.db_password
}

module "elasticache" {
  source             = "./modules/elasticache"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_app_id          = module.vpc.sg_app_id
}

# ── Publica endpoints no SSM (consumidos por EC2, Lambda e ECS) ───────────────
resource "aws_ssm_parameter" "db_host" {
  name  = "/lanchonete/prod/db_host"
  type  = "String"
  value = module.rds.db_host
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/lanchonete/prod/db_password"
  type  = "SecureString"
  value = var.db_password
}

resource "aws_ssm_parameter" "redis_host" {
  name  = "/lanchonete/prod/redis_host"
  type  = "String"
  value = module.elasticache.primary_endpoint
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "vpc_id"             { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
output "public_subnet_ids"  { value = module.vpc.public_subnet_ids }
output "sg_app_id"          { value = module.vpc.sg_app_id }
output "sg_alb_id"          { value = module.vpc.sg_alb_id }
output "db_endpoint"        { value = module.rds.db_endpoint }
output "db_host"            { value = module.rds.db_host }
output "redis_host"         { value = module.elasticache.primary_endpoint }
