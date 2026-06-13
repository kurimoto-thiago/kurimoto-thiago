variable "project" { type = string }
variable "environment" { type = string }

variable "password_min_length" {
  type    = number
  default = 14
}

variable "password_max_age_days" {
  type    = number
  default = 90
}

variable "analyzer_type" {
  type    = string
  default = "ACCOUNT"
  validation {
    condition     = contains(["ACCOUNT", "ORGANIZATION"], var.analyzer_type)
    error_message = "Type must be ACCOUNT or ORGANIZATION"
  }
}

variable "create_power_user_role" {
  type    = bool
  default = true
}

variable "create_auditor_role" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
