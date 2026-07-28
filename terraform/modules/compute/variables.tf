variable "name_prefix" {
  description = "Prefix for resource names, e.g. momosim-dev"
  type        = string
}

variable "server_role" {
  description = "What this instance is for — becomes the Name tag suffix (e.g. app-server, bastion)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance into"
  type        = string
}

variable "security_group_ids" {
  description = "Security groups to attach to the instance"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access (created once in the root module)"
  type        = string
}

variable "associate_public_ip" {
  description = "Whether the instance gets a public IP (true for the bastion, false for the app server)"
  type        = bool
  default     = false
}

variable "iam_instance_profile" {
  description = "IAM instance profile to attach (e.g. the ECR pull role), or null for none"
  type        = string
  default     = null
}

variable "source_dest_check" {
  description = "Whether AWS drops packets not addressed to/from this instance (must be false for a NAT instance)"
  type        = bool
  default     = true
}

variable "user_data" {
  description = "Cloud-init / shell script to run on first boot, or null for none"
  type        = string
  default     = null
}

variable "root_volume_size_gb" {
  description = "Size of the instance's root EBS volume in GB"
  type        = number
  default     = 10
}

variable "root_volume_type" {
  description = "EBS volume type for the root disk"
  type        = string
  default     = "gp3"
}

variable "ami_owner_id" {
  description = "AWS account ID that publishes the AMI (default: Canonical)"
  type        = string
  default     = "099720109477"
}

variable "ami_name_pattern" {
  description = "Name pattern used to find the latest AMI"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}
