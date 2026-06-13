variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.29"
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type    = list(string)
  default = []
}

variable "endpoint_public_access" {
  description = "Allow public access to API endpoint (restrict in prod!)"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to access public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_security_group_ids" {
  type    = list(string)
  default = []
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "node_groups" {
  description = "Map of node group configurations"
  type        = any
  default = {
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      labels         = { role = "system" }
    }
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
