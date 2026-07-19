# =============================================================================
# Terraform and provider version constraints.
# Pinning versions keeps `terraform init` reproducible for every team member —
# the same provider code runs on every machine and in CI.
# =============================================================================
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
