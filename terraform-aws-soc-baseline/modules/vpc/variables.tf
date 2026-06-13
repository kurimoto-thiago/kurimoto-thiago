variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to use"
  type        = list(string)
}

variable "subnet_newbits" {
  description = "Subnet CIDR newbits"
  type        = number
  default     = 4
}

variable "create_database_subnets" {
  description = "Create isolated database subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT for cost saving (NOT recommended for prod)"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Days to retain Flow Logs"
  type        = number
  default     = 30
}

variable "flow_logs_kms_key_arn" {
  description = "KMS key ARN for Flow Logs encryption"
  type        = string
  default     = null
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for S3 and DynamoDB"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
