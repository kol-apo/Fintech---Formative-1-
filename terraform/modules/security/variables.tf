variable "name_prefix" {
  description = "Prefix for resource names, e.g. momosim-dev"
  type        = string
}

variable "vpc_id" {
  description = "VPC the security group belongs to"
  type        = string
}

variable "app_port" {
  description = "Application port to expose publicly"
  type        = number
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to reach the SSH port"
  type        = string
}

variable "ssh_port" {
  description = "Port the SSH daemon listens on"
  type        = number
  default     = 22
}

variable "app_allowed_cidr" {
  description = "CIDR block allowed to reach the app port (public API by default)"
  type        = string
  default     = "0.0.0.0/0"
}
