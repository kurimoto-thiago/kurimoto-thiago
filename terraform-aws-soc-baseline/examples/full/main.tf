# Exemplo completo: VPC + Security + Logging + IAM + EKS
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.30" }
  }
}

provider "aws" {
  region = "sa-east-1"

  default_tags {
    tags = {
      Project     = "soc-baseline"
      Environment = "prod"
      Owner       = "thiago.kurimoto"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  project     = "soc-baseline"
  environment = "prod"
  azs         = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
  tags = {
    Project     = local.project
    Environment = local.environment
  }
}

# ============================================================
# Network
# ============================================================
module "vpc" {
  source = "../../modules/vpc"

  name               = local.project
  cidr               = "10.10.0.0/16"
  availability_zones = local.azs

  enable_flow_logs        = true
  enable_vpc_endpoints    = true
  create_database_subnets = true

  tags = local.tags
}

# ============================================================
# IAM hardening
# ============================================================
module "iam" {
  source = "../../modules/iam-baseline"

  project     = local.project
  environment = local.environment

  password_min_length    = 16
  password_max_age_days  = 60
  create_power_user_role = true
  create_auditor_role    = true

  tags = local.tags
}

# ============================================================
# Security services
# ============================================================
module "security" {
  source = "../../modules/security-baseline"

  project     = local.project
  environment = local.environment

  enable_guardduty    = true
  enable_config       = true
  enable_inspector    = true
  enable_macie        = true
  enable_security_hub = true

  tags = local.tags
}

# ============================================================
# Logging (CloudTrail + S3 + Athena)
# ============================================================
module "logging" {
  source = "../../modules/logging"

  project                    = local.project
  retention_days             = 2555  # 7 anos
  enable_object_lock         = true
  object_lock_retention_days = 365
  create_athena_workgroup    = true

  tags = local.tags
}

# ============================================================
# EKS cluster
# ============================================================
module "eks" {
  source = "../../modules/eks-baseline"

  cluster_name       = local.project
  cluster_version    = "1.29"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  endpoint_public_access = false  # private only em prod
  log_retention_days     = 90

  node_groups = {
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      labels         = { role = "system" }
    }
    apps = {
      instance_types = ["t3.large", "t3a.large"]
      capacity_type  = "SPOT"
      min_size       = 2
      max_size       = 6
      desired_size   = 3
      labels         = { role = "apps" }
    }
  }

  tags = local.tags
}

# ============================================================
# Outputs
# ============================================================
output "vpc_id"           { value = module.vpc.vpc_id }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_name"     { value = module.eks.cluster_name }
output "logs_bucket"      { value = module.logging.logs_bucket }
