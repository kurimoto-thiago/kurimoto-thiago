# ============================================================
# terraform-aws-soc-baseline/modules/iam-baseline
# Password policy, MFA enforcement, Access Analyzer
# ============================================================

terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.30" }
  }
}

# ============================================================
# Account password policy (CIS 1.5-1.11)
# ============================================================
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = var.password_min_length
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  hard_expiry                    = false
  max_password_age               = var.password_max_age_days
  password_reuse_prevention      = 24
}

# ============================================================
# IAM Access Analyzer
# ============================================================
resource "aws_accessanalyzer_analyzer" "this" {
  analyzer_name = "${var.project}-${var.environment}"
  type          = var.analyzer_type

  tags = var.tags
}

# ============================================================
# Force MFA policy (anexar em grupos/users)
# ============================================================
data "aws_iam_policy_document" "force_mfa" {
  statement {
    sid    = "AllowViewAccountInfo"
    effect = "Allow"
    actions = [
      "iam:GetAccountPasswordPolicy",
      "iam:ListVirtualMFADevices"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowManageOwnPasswords"
    effect = "Allow"
    actions = [
      "iam:ChangePassword",
      "iam:GetUser"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }

  statement {
    sid    = "AllowManageOwnVirtualMFADevice"
    effect = "Allow"
    actions = [
      "iam:CreateVirtualMFADevice"
    ]
    resources = ["arn:aws:iam::*:mfa/*"]
  }

  statement {
    sid    = "AllowManageOwnUserMFA"
    effect = "Allow"
    actions = [
      "iam:DeactivateMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ResyncMFADevice"
    ]
    resources = ["arn:aws:iam::*:user/$${aws:username}"]
  }

  statement {
    sid    = "DenyAllExceptListedIfNoMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:GetUser",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      "iam:ResyncMFADevice",
      "sts:GetSessionToken"
    ]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "force_mfa" {
  name        = "${var.project}-${var.environment}-force-mfa"
  description = "Force MFA for IAM users"
  policy      = data.aws_iam_policy_document.force_mfa.json

  tags = var.tags
}

# ============================================================
# Power user role (assumível com MFA)
# ============================================================
resource "aws_iam_role" "power_user" {
  count = var.create_power_user_role ? 1 : 0
  name  = "${var.project}-${var.environment}-power-user"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        Bool = { "aws:MultiFactorAuthPresent" = "true" }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "power_user" {
  count      = var.create_power_user_role ? 1 : 0
  role       = aws_iam_role.power_user[0].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# ============================================================
# Read-only role (auditoria)
# ============================================================
resource "aws_iam_role" "auditor" {
  count = var.create_auditor_role ? 1 : 0
  name  = "${var.project}-${var.environment}-auditor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "auditor" {
  count      = var.create_auditor_role ? 1 : 0
  role       = aws_iam_role.auditor[0].name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

data "aws_caller_identity" "current" {}
