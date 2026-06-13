output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "VPC CIDR block"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnet IDs"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Private subnet IDs"
}

output "database_subnet_ids" {
  value       = aws_subnet.database[*].id
  description = "Database subnet IDs"
}

output "nat_gateway_ips" {
  value       = aws_eip.nat[*].public_ip
  description = "NAT Gateway public IPs (for whitelisting)"
}

output "flow_logs_log_group" {
  value       = try(aws_cloudwatch_log_group.flow_logs[0].name, null)
  description = "CloudWatch Log Group name for Flow Logs"
}
