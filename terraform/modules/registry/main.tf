# =============================================================================
# Registry module — private container registry (ECR).
#
# The CD pipeline pushes the freshly built image here; the app server pulls
# it via its IAM instance role (see modules/iam) — no registry passwords
# anywhere. scan_on_push gives every pushed image a vulnerability scan on
# the registry side, complementing the Trivy scan in CI.
# =============================================================================

resource "aws_ecr_repository" "app" {
  name = var.repository_name

  # MUTABLE because the deploy flow re-points a moving tag (e.g. :latest)
  # at each release and the VM just pulls that tag. Immutable tags would
  # force docker-compose changes on every deploy for no security gain here —
  # each push is also tagged with the commit SHA for traceability.
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # AES256 = SSE with an AWS-managed key. A customer-managed KMS key would
  # add cost and key-rotation ceremony without a requirement driving it.
  encryption_configuration {
    encryption_type = "AES256"
  }

  # Let `terraform destroy` remove the repository even when images exist —
  # this environment is torn down and rebuilt repeatedly
  force_delete = true

  tags = {
    Name = var.repository_name
  }
}

# Keep the registry from growing without bound: every CD run pushes an image,
# so cap history at the newest N and let AWS expire the rest.
resource "aws_ecr_lifecycle_policy" "keep_recent" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the ${var.max_image_count} most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
