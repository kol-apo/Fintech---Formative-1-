variable "name_prefix" {
  description = "Prefix for resource names, e.g. momosim-dev"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the app server is allowed to pull from"
  type        = string
}
