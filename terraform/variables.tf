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

# --- Network -----------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (bastion; subnets are free, so two keeps AZ options open)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (app server + database; two AZs required)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# --- Compute -----------------------------------------------------------------

# The team account is on AWS's credits-based FREE plan (verified 2026-07-25:
# it cannot be billed; usage draws from ~$98 of credits until 2027-01-21).
# Under credits everything is charged at list price, and in eu-west-1
# t3.micro is both cheaper per hour than t2.micro and twice the vCPUs —
# so t3.micro it is, with CPU bursting capped in the compute module.
variable "instance_type" {
  description = "EC2 instance type for the application server"
  type        = string
  default     = "t3.micro"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion (sshd + iptables only, so smallest works)"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port the MoMoSim container listens on"
  type        = number
  default     = 3000
}

variable "public_http_port" {
  description = "Public port the bastion listens on for web traffic (forwarded to the app server)"
  type        = number
  default     = 80
}

variable "ssh_allowed_cidrs" {
  description = <<-EOT
    CIDR blocks allowed to SSH into the BASTION (the app server only accepts
    SSH from the bastion). Deliberately has NO default: each entry should be
    one team member's IP (e.g. "41.90.x.x/32") so we never accidentally open
    port 22 to the whole internet.
  EOT
  type        = list(string)

  validation {
    condition = (
      length(var.ssh_allowed_cidrs) > 0 &&
      alltrue([for c in var.ssh_allowed_cidrs : can(cidrhost(c, 0))])
    )
    error_message = "ssh_allowed_cidrs must contain at least one valid CIDR block, e.g. [\"41.90.10.5/32\"]."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key uploaded to AWS for instance access"
  type        = string
  default     = "~/.ssh/momosim.pub"
}

# --- Database ----------------------------------------------------------------

variable "db_name" {
  description = "Name of the initial database created on the RDS instance"
  type        = string
  default     = "momosim"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "momosim"
}

variable "db_password" {
  description = <<-EOT
    Master password for the database. Deliberately has NO default — set it in
    the gitignored secrets.auto.tfvars, next to the AWS keys. Marked sensitive
    so Terraform redacts it from plan output.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "db_password must be at least 12 characters."
  }
}

variable "db_port" {
  description = "Port the database listens on"
  type        = number
  default     = 5432
}

variable "db_engine_version" {
  description = "PostgreSQL major version for RDS"
  type        = string
  default     = "16"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}
