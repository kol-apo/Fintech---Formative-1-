variable "name_prefix" {
  description = "Prefix for resource names, e.g. momosim-dev"
  type        = string
}

variable "vpc_id" {
  description = "VPC the security groups belong to"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR of the VPC — the bastion accepts NAT-forwarded traffic from this range"
  type        = string
}

variable "app_port" {
  description = "Port the application container listens on"
  type        = number
}

variable "public_http_port" {
  description = "Public port the bastion listens on for web traffic (forwarded to the app)"
  type        = number
  default     = 80
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to reach the bastion's SSH port (one per operator)"
  type        = list(string)
}

variable "ssh_port" {
  description = "Port the SSH daemon listens on"
  type        = number
  default     = 22
}

variable "db_port" {
  description = "Port the database listens on"
  type        = number
  default     = 5432
}
