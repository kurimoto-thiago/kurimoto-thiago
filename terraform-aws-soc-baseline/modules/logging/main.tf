# ============================================================
# terraform-aws-soc-baseline/modules/logging
# CloudTrail multi-region + S3 com Object Lock + Athena
# ============================================================

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.30" }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# ============================================================
# KMS key para criptografar logs
# ============================================================
resource "aws_kms_key" "logs" {
  description             = "${var.project} CloudTrail/logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_logs.json
  tags                    = var.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.project}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

data "aws_iam_policy_document" "kms_logs" {
  statement {
    sid       = "EnableIAM"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid    = "CloudTrailUseKey"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

# ============================================================
# S3 bucket com Object Lock (WORM - imutável)
# ============================================================
resource "aws_s3_bucket" "logs" {
  bucket              = "${var.project}-logs-${local.account_id}"
  object_lock_enabled = var.enable_object_lock
  force_destroy       = false
  tags                = var.tags
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "logs" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.logs.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.object_lock_retention_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = var.retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs_bucket.json
}

data "aws_iam_policy_document" "logs_bucket" {
  statement {
    sid     = "CloudTrailACLCheck"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [aws_s3_bucket.logs.arn]
  }

  statement {
    sid     = "CloudTrailWrite"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.logs.arn}/AWSLogs/${local.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# ============================================================
# CloudTrail multi-region
# ============================================================
resource "aws_cloudtrail" "this" {
  name                          = "${var.project}-trail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = false
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.logs.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = var.tags

  depends_on = [aws_s3_bucket_policy.logs]
}

# ============================================================
# Athena workgroup para queries
# ============================================================
resource "aws_athena_workgroup" "logs" {
  count = var.create_athena_workgroup ? 1 : 0
  name  = "${var.project}-logs"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.logs.id}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.logs.arn
      }
    }
  }

  tags = var.tags
}
