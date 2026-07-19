# =============================================================================
# Root input variables.
# Everything environment-specific lives here — regions, CIDR ranges, instance
# sizes — so the same code can provision dev, staging, or prod by swapping a
# single .tfvars file. Nothing sensitive has a default committed to the repo.
# =============================================================================

variable "project_name" {
  description = "Short name used as a prefix for all resource names"
  type        = string
  default     = "momosim"
}

variable "environment" {
  description = "Deployment environment (dev, staging, or prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = <<-EOT
    Named AWS credentials profile to use (from ~/.aws/credentials). We use
    "momosim-team" so it's always explicit that Terraform is acting on the
    TEAM account, not anyone's personal one. Set to null to fall back to
    environment variables / the default profile.
  EOT
  type        = string
  default     = "momosim-team"
}

# --- Credentials (supplied via secrets.auto.tfvars, which is gitignored) ----
# Marked sensitive so Terraform redacts them from plan output and logs.
# If left null, Terraform falls back to the aws_profile above.

variable "aws_access_key" {
  description = "Team AWS access key ID (set in secrets.auto.tfvars, never committed)"
  type        = string
  default     = null
  sensitive   = true
}

variable "aws_secret_key" {
  description = "Team AWS secret access key (set in secrets.auto.tfvars, never committed)"
  type        = string
  default     = null
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (must sit inside vpc_cidr)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the application server"
  type        = string
  default     = "t3.micro" # free-tier eligible in most regions
}

variable "app_port" {
  description = "Port the MoMoSim container listens on"
  type        = number
  default     = 3000
}

variable "ssh_allowed_cidr" {
  description = <<-EOT
    CIDR block allowed to SSH into the instance. Deliberately has NO default:
    each engineer must supply their own IP (e.g. "41.90.x.x/32") so we never
    accidentally open port 22 to the whole internet.
  EOT
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid CIDR block, e.g. 41.90.10.5/32."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key uploaded to AWS for instance access"
  type        = string
  default     = "~/.ssh/momosim.pub"
}
