output "cloudtrail_arn" { value = aws_cloudtrail.this.arn }
output "logs_bucket" { value = aws_s3_bucket.logs.id }
output "logs_kms_key_arn" { value = aws_kms_key.logs.arn }
output "athena_workgroup" { value = try(aws_athena_workgroup.logs[0].name, null) }
