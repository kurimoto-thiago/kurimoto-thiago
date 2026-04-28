# infra/ec2-3tier/main.tf
# Arquitetura 3 camadas — Web | App | BD — tudo em EC2
# Compatível com AWS Learner Labs (us-east-1, LabInstanceProfile)

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = { Project = "lanchonete", ManagedBy = "Terraform" }
  }
}

variable "db_password" {
  description = "Senha do PostgreSQL"
  default     = "LanchonetePass123!"
  sensitive   = true
}

variable "key_name" {
  description = "Par de chaves EC2 (vockey no Learner Labs)"
  default     = "vockey"
}

# AMI — Amazon Linux 2023 mais recente (us-east-1, x86_64)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "lanchonete-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "lanchonete-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "lanchonete-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "lanchonete-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ── Security Groups ───────────────────────────────────────────────────────────

# Camada 1 — Web: HTTP público
resource "aws_security_group" "web" {
  name        = "lanchonete-web"
  description = "Camada web — HTTP publico"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP da internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lanchonete-web-sg", Camada = "web" }
}

# Camada 2 — App: aceita somente da camada web
resource "aws_security_group" "app" {
  name        = "lanchonete-app"
  description = "Camada app — somente da camada web"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Node.js da camada web"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lanchonete-app-sg", Camada = "app" }
}

# Camada 3 — BD: aceita somente da camada app
resource "aws_security_group" "db" {
  name        = "lanchonete-db"
  description = "Camada BD — somente da camada app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "Redis"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lanchonete-db-sg", Camada = "db" }
}

# ── Camada 3 — BD (PostgreSQL + Redis) ───────────────────────────────────────
resource "aws_instance" "db" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.db.id]
  iam_instance_profile        = "LabInstanceProfile"
  key_name                    = var.key_name
  associate_public_ip_address = true # necessário para download de pacotes

  user_data = templatefile("${path.module}/user_data_db.sh", {
    DB_PASSWORD = var.db_password
  })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = { Name = "lanchonete-db", Camada = "3-bd" }
}

# ── Camada 2 — App (Node.js) ─────────────────────────────────────────────────
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  iam_instance_profile        = "LabInstanceProfile"
  key_name                    = var.key_name
  associate_public_ip_address = true # necessário para download de pacotes

  user_data = templatefile("${path.module}/user_data_app.sh", {
    DB_HOST     = aws_instance.db.private_ip
    DB_PASSWORD = var.db_password
    REDIS_HOST  = aws_instance.db.private_ip
  })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = { Name = "lanchonete-app", Camada = "2-app" }
}

# ── Camada 1 — Web (Nginx + frontend) ────────────────────────────────────────
resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = "LabInstanceProfile"
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data_web.sh", {
    APP_HOST = aws_instance.app.private_ip
  })

  root_block_device {
    volume_size           = 10
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = { Name = "lanchonete-web", Camada = "1-web" }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "url" {
  value       = "http://${aws_instance.web.public_ip}"
  description = "URL pública do sistema"
}

output "web_ip"  { value = aws_instance.web.public_ip }
output "app_ip"  { value = aws_instance.app.private_ip }
output "db_ip"   { value = aws_instance.db.private_ip }
