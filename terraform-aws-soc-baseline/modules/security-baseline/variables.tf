variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "enable_guardduty" {
  type    = bool
  default = true
}

variable "enable_config" {
  type    = bool
  default = true
}

variable "enable_inspector" {
  type    = bool
  default = true
}

variable "enable_macie" {
  type        = bool
  default     = false
  description = "Caro — habilite apenas em prod com S3 sensível"
}

variable "enable_security_hub" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
