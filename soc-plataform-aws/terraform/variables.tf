variable "region" {
  description = "AWS region"
  type        = string
  default     = "sa-east-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "soc-platform"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging or prod."
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs"
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
}

variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "soc.seudominio.dev"
}

variable "alert_slack_webhook" {
  description = "Slack webhook for alerts"
  type        = string
  sensitive   = true
  default     = ""
}
