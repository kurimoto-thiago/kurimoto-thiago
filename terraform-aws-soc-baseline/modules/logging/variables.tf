variable "project" { type = string }

variable "retention_days" {
  type    = number
  default = 2555  # 7 anos
}

variable "enable_object_lock" {
  description = "Object Lock previne modificação/deleção (compliance)"
  type        = bool
  default     = true
}

variable "object_lock_retention_days" {
  type    = number
  default = 365
}

variable "create_athena_workgroup" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
