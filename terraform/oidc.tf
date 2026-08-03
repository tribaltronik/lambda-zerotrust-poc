# GitHub OIDC Identity Provider
# Skipped when targeting Floci (not supported by local emulator)
resource "aws_iam_openid_connect_provider" "github" {
  count = var.use_localstack ? 0 : 1

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Project = var.project_name
  }
}

# IAM Role for GitHub Actions (zero-trust: no long-lived credentials)
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = var.use_localstack ? {
          AWS = "arn:aws:iam::000000000000:root"
          } : {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = var.use_localstack ? "sts:AssumeRole" : "sts:AssumeRoleWithWebIdentity"
        Condition = var.use_localstack ? {} : {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  max_session_duration = 3600

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}
