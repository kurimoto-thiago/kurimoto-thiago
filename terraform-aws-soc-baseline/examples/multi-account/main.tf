# Exemplo multi-account com AWS Organizations
# Padrão: 1 conta de segurança central + N contas spoke

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.30"
      configuration_aliases = [aws.security, aws.workload]
    }
  }
}

# Provider para conta de segurança (logs centralizados)
provider "aws" {
  alias  = "security"
  region = "sa-east-1"
  assume_role {
    role_arn = "arn:aws:iam::SECURITY_ACCOUNT_ID:role/OrganizationAccountAccessRole"
  }
}

# Provider para conta de workload
provider "aws" {
  alias  = "workload"
  region = "sa-east-1"
  assume_role {
    role_arn = "arn:aws:iam::WORKLOAD_ACCOUNT_ID:role/OrganizationAccountAccessRole"
  }
}

# Logging centralizado na conta de segurança
module "central_logging" {
  source = "../../modules/logging"
  providers = { aws = aws.security }

  project = "org-central"
  retention_days = 2555
}

# VPC na conta de workload
module "workload_vpc" {
  source = "../../modules/vpc"
  providers = { aws = aws.workload }

  name               = "workload-prod"
  cidr               = "10.20.0.0/16"
  availability_zones = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
}
