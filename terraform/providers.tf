# =============================================================================
# AWS provider configuration.
# The region comes from a variable (never hardcoded) and credentials come from
# the environment (aws configure / AWS_ACCESS_KEY_ID env vars) — no secrets
# ever appear in this repository.
#
# default_tags stamps every resource we create with project/environment tags,
# so anything provisioned by this configuration is identifiable (and easy to
# find and destroy) in the AWS console.
# =============================================================================
# Credentials come from terraform/secrets.auto.tfvars (gitignored). If that
# file is absent, the keys are null and Terraform falls back to the named
# profile in ~/.aws/credentials instead — either path works, secrets file wins.
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  profile    = var.aws_access_key == null ? var.aws_profile : null

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
