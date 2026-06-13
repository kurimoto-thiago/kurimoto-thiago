# Module: iam-baseline

IAM hardening alinhado com CIS AWS Benchmark.

## Features
- Account password policy (14+ chars, expiração 90d, no reuse de 24 últimas)
- IAM Access Analyzer
- Policy `force-mfa` (anexar em grupos/users)
- Roles assumíveis: power-user (com MFA) e auditor (read-only)

## Usage

```hcl
module "iam" {
  source = "github.com/kurimoto-thiago/terraform-aws-soc-baseline//modules/iam-baseline?ref=v1.0.0"

  project     = "soc"
  environment = "prod"

  password_min_length    = 16
  password_max_age_days  = 60
  create_power_user_role = true
  create_auditor_role    = true
}

# Anexar force-mfa em grupo
resource "aws_iam_group_policy_attachment" "dev_team_mfa" {
  group      = aws_iam_group.developers.name
  policy_arn = module.iam.force_mfa_policy_arn
}
```
