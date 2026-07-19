variable "name_prefix" {
  description = "Prefix for resource names, e.g. momosim-dev"
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

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file to upload as a key pair"
  type        = string
}
