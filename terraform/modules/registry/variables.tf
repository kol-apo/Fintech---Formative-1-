variable "repository_name" {
  description = "Name of the ECR repository (lowercase, e.g. momosim-dev)"
  type        = string
}

variable "max_image_count" {
  description = "How many images the lifecycle policy keeps before expiring the oldest"
  type        = number
  default     = 10
}
