variable "name_prefix" {
  description = "Prefix for resource names, e.g. momosim-dev"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (subnets are free — a second one keeps AZ options open)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 1
    error_message = "At least one public subnet CIDR is required (the bastion lives there)."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ, at least two for the RDS subnet group)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs are required (the RDS subnet group spans two AZs)."
  }
}
