terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  backend "s3" {
    bucket         = "soc-platform-tfstate"
    key            = "infra/terraform.tfstate"
    region         = "sa-east-1"
    encrypt        = true
    dynamodb_table = "soc-platform-tflock"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "soc-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "thiago.kurimoto"
      CostCenter  = "portfolio"
    }
  }
}

# ============================================================
# VPC
# ============================================================
module "vpc" {
  source = "./modules/vpc"

  name               = "${var.project}-${var.environment}"
  cidr               = var.vpc_cidr
  availability_zones = var.availability_zones
  environment        = var.environment
}

# ============================================================
# EKS
# ============================================================
module "eks" {
  source = "./modules/eks"

  cluster_name        = "${var.project}-${var.environment}"
  cluster_version     = "1.29"
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  environment         = var.environment

  node_groups = {
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      labels         = { role = "system" }
      taints = [{
        key    = "dedicated"
        value  = "system"
        effect = "NO_SCHEDULE"
      }]
    }
    apps = {
      instance_types = ["t3.large", "t3a.large"]
      capacity_type  = "SPOT"
      min_size       = 2
      max_size       = 6
      desired_size   = 3
      labels         = { role = "apps" }
    }
    monitoring = {
      instance_types = ["t3.xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      labels         = { role = "monitoring" }
    }
  }
}

# ============================================================
# RDS
# ============================================================
module "rds" {
  source = "./modules/rds"

  identifier         = "${var.project}-${var.environment}"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  allowed_cidrs      = [var.vpc_cidr]
  engine_version     = "15.5"
  instance_class     = var.environment == "prod" ? "db.t4g.medium" : "db.t4g.micro"
  allocated_storage  = 50
  multi_az           = var.environment == "prod"
  database_name      = "socplatform"
  master_username    = "socadmin"
  environment        = var.environment
}

# ============================================================
# ElastiCache Redis
# ============================================================
module "redis" {
  source = "./modules/redis"

  cluster_id     = "${var.project}-${var.environment}"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  allowed_cidrs  = [var.vpc_cidr]
  node_type      = "cache.t4g.micro"
  num_cache_nodes = var.environment == "prod" ? 2 : 1
  environment    = var.environment
}

# ============================================================
# Security services
# ============================================================
module "security" {
  source = "./modules/security"

  project     = var.project
  environment = var.environment
  region      = var.region

  enable_guardduty = true
  enable_config    = true
  enable_inspector = true
  enable_macie     = var.environment == "prod"
}

# ============================================================
# Outputs
# ============================================================
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "rds_endpoint" {
  value     = module.rds.endpoint
  sensitive = true
}

output "redis_endpoint" {
  value     = module.redis.endpoint
  sensitive = true
}
