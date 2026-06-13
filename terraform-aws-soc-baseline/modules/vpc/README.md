# Module: vpc

VPC multi-AZ com defaults seguros para SOC.

## Features
- Multi-AZ subnets (public, private, database)
- NAT Gateway por AZ (HA) — opcional single NAT para DEV
- VPC Flow Logs habilitados por padrão → CloudWatch
- VPC Endpoints S3 e DynamoDB (reduz custo + tráfego privado)
- Tags Kubernetes prontas para EKS

## Usage

```hcl
module "vpc" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/vpc?ref=v1.0.0"

  name               = "soc"
  cidr               = "10.0.0.0/16"
  availability_zones = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]

  enable_flow_logs        = true
  enable_vpc_endpoints    = true
  create_database_subnets = true

  tags = {
    Project     = "soc"
    Environment = "prod"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Prefix for resources | string | - | yes |
| cidr | VPC CIDR | string | 10.0.0.0/16 | no |
| availability_zones | AZ list | list(string) | - | yes |
| single_nat_gateway | Cost-saving single NAT | bool | false | no |
| enable_flow_logs | Enable Flow Logs | bool | true | no |
| enable_vpc_endpoints | S3/DynamoDB endpoints | bool | true | no |
| tags | Common tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| public_subnet_ids | Public subnet IDs |
| private_subnet_ids | Private subnet IDs |
| database_subnet_ids | Database subnet IDs |
| nat_gateway_ips | NAT public IPs |

## Compliance

- ✅ CIS AWS 1.5 (Flow Logs enabled)
- ✅ CKV_AWS_111 (Flow Logs)
- ✅ CKV_AWS_130 (subnet does not auto-assign public IP in private subnets)
