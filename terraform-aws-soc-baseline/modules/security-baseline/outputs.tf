output "guardduty_detector_id" {
  value = try(aws_guardduty_detector.this[0].id, null)
}

output "config_bucket" {
  value = try(aws_s3_bucket.config[0].id, null)
}

output "security_hub_enabled" {
  value = var.enable_security_hub
}
