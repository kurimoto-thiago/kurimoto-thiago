variable "project" {}
variable "environment" {}
variable "region" {}
variable "enable_guardduty" { default = true }
variable "enable_config" { default = true }
variable "enable_inspector" { default = true }
variable "enable_macie" { default = false }

# ============================================================
# GuardDuty
# ============================================================
resource "aws_guardduty_detector" "this" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs { enable = true }
    kubernetes {
      audit_logs { enable = true }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes { enable = true }
      }
    }
  }
}

# ============================================================
# AWS Config
# ============================================================
resource "aws_s3_bucket" "config" {
  count         = var.enable_config ? 1 : 0
  bucket        = "${var.project}-${var.environment}-config-${var.region}"
  force_destroy = var.environment != "prod"
}

resource "aws_s3_bucket_public_access_block" "config" {
  count                   = var.enable_config ? 1 : 0
  bucket                  = aws_s3_bucket.config[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0
  name  = "${var.project}-${var.environment}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# ============================================================
# Inspector
# ============================================================
resource "aws_inspector2_enabler" "this" {
  count           = var.enable_inspector ? 1 : 0
  account_ids     = [data.aws_caller_identity.current.account_id]
  resource_types  = ["EC2", "ECR", "LAMBDA"]
}

data "aws_caller_identity" "current" {}

# ============================================================
# Macie
# ============================================================
resource "aws_macie2_account" "this" {
  count                        = var.enable_macie ? 1 : 0
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}
