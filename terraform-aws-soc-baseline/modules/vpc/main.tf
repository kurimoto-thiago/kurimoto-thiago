# ============================================================
# terraform-aws-soc-baseline/modules/vpc
# VPC multi-AZ com Flow Logs, NAT por AZ, VPC Endpoints
# ============================================================

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.30" }
  }
}

# ============================================================
# VPC
# ============================================================
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
  })
}

# ============================================================
# Internet Gateway
# ============================================================
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# ============================================================
# Public subnets
# ============================================================
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, var.subnet_newbits, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                    = "${var.name}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                = "1"
    "kubernetes.io/cluster/${var.name}"     = "shared"
    Tier                                    = "public"
  })
}

# ============================================================
# Private subnets
# ============================================================
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, var.subnet_newbits, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                                    = "${var.name}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"       = "1"
    "kubernetes.io/cluster/${var.name}"     = "shared"
    Tier                                    = "private"
  })
}

# ============================================================
# Database subnets (isoladas, sem internet)
# ============================================================
resource "aws_subnet" "database" {
  count             = var.create_database_subnets ? length(var.availability_zones) : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr, var.subnet_newbits, count.index + (length(var.availability_zones) * 2))
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-database-${var.availability_zones[count.index]}"
    Tier = "database"
  })
}

# ============================================================
# NAT Gateways
# ============================================================
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.this]
}

# ============================================================
# Route tables
# ============================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = merge(var.tags, { Name = "${var.name}-private-rt-${count.index}" })
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ============================================================
# VPC Flow Logs (CRÍTICO para SOC)
# ============================================================
resource "aws_cloudwatch_log_group" "flow_logs" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.flow_logs_kms_key_arn
  tags              = var.tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.name}-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  role  = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count           = var.enable_flow_logs ? 1 : 0
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id
  tags            = var.tags
}

# ============================================================
# VPC Endpoints (custo + segurança — tráfego sem sair pra internet)
# ============================================================
resource "aws_vpc_endpoint" "s3" {
  count        = var.enable_vpc_endpoints ? 1 : 0
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  route_table_ids = aws_route_table.private[*].id
  tags         = merge(var.tags, { Name = "${var.name}-s3-endpoint" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count           = var.enable_vpc_endpoints ? 1 : 0
  vpc_id          = aws_vpc.this.id
  service_name    = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  route_table_ids = aws_route_table.private[*].id
  tags            = merge(var.tags, { Name = "${var.name}-dynamodb-endpoint" })
}

data "aws_region" "current" {}
