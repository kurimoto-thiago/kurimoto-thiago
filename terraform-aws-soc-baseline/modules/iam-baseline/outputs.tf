output "force_mfa_policy_arn" {
  value = aws_iam_policy.force_mfa.arn
}

output "power_user_role_arn" {
  value = try(aws_iam_role.power_user[0].arn, null)
}

output "auditor_role_arn" {
  value = try(aws_iam_role.auditor[0].arn, null)
}

output "access_analyzer_arn" {
  value = aws_accessanalyzer_analyzer.this.arn
}
