# Exemplo mínimo: apenas VPC
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.30" }
  }
}

provider "aws" {
  region = "sa-east-1"
}

module "vpc" {
  source = "../../modules/vpc"

  name               = "my-minimal-project"
  cidr               = "10.0.0.0/16"
  availability_zones = ["sa-east-1a", "sa-east-1b"]

  single_nat_gateway = true  # economia em dev
  enable_flow_logs   = true

  tags = {
    Project     = "minimal-example"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

output "vpc_id" { value = module.vpc.vpc_id }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
