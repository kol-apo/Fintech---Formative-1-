variable "name_prefix" {
  description = "Prefix for resource names, e.g. momosim-dev"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (at least two AZs)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups controlling who can connect to the database"
  type        = list(string)
}

variable "db_name" {
  description = "Name of the initial database created on the instance"
  type        = string
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
}

variable "db_password" {
  description = "Master password for the database (from secrets.auto.tfvars, never committed)"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port the database listens on"
  type        = number
  default     = 5432
}

variable "engine_version" {
  description = "PostgreSQL major version (RDS picks the latest minor release)"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage_gb" {
  description = "Storage allocated to the database in GB"
  type        = number
  default     = 20
}
