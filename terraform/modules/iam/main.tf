# =============================================================================
# IAM module — the app server's identity for pulling images from ECR.
#
# Instead of storing registry credentials on the VM (or worse, in the repo),
# the instance gets a role whose policy allows pulling from exactly ONE
# repository — ours. `aws ecr get-login-password` on the instance then works
# with no long-lived secrets anywhere, and a compromised app server still
# can't read any other repository, push images, or touch other services.
# =============================================================================

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name = "${var.name_prefix}-app-role"
  }
}

data "aws_iam_policy_document" "ecr_pull" {
  # GetAuthorizationToken is account-wide by design — AWS does not support
  # scoping it to a repository. The token alone grants nothing; every actual
  # pull is checked against the repository-scoped statement below.
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPullOurRepoOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "ecr_pull" {
  name   = "${var.name_prefix}-ecr-pull"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.ecr_pull.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name_prefix}-app-profile"
  role = aws_iam_role.app.name
}
