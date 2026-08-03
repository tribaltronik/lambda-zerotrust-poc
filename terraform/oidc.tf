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

locals {
  # One IAM role per environment, so dev and prod can be gated independently.
  github_actions_environments = toset(["dev", "prod"])

  # Branch-scoped `sub` conditions per environment. A StringLike condition key
  # holding a LIST of patterns is OR'd by IAM, so dev's single Statement covers
  # both branch pushes and PRs. prod is locked to main only.
  github_actions_sub_patterns = {
    dev = [
      "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*",
      "repo:${var.github_org}/${var.github_repo}:ref:refs/pull/*",
    ]
    prod = [
      "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
    ]
  }

  # Least-privilege policy for Terraform deploys: scoped to this stack's
  # resources (all prefixed ${var.project_name}) + the remote-state backend.
  # Actions that AWS does not allow to be resource-scoped (list/global calls)
  # live in separate statements with Resource = ["*"].
  github_actions_terraform_policy = {
    Version = "2012-10-17"
    Statement = [
      # --- S3 remote state (backend-aws.tfvars: bucket + dev key prefix) ---
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["arn:aws:s3:::${var.project_name}-terraform-state/${var.project_name}/${var.environment}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetBucketVersioning"]
        Resource = ["arn:aws:s3:::${var.project_name}-terraform-state"]
      },
      # --- DynamoDB state lock table ---
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = ["arn:aws:dynamodb:*:*:table/${var.project_name}-terraform-locks"]
      },
      # --- DynamoDB app table (aws_dynamodb_table, table CRUD + tags) ---
      {
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable", "dynamodb:DescribeTable", "dynamodb:DeleteTable",
          "dynamodb:UpdateTable", "dynamodb:TagResource", "dynamodb:UntagResource",
        ]
        Resource = ["arn:aws:dynamodb:*:*:table/${var.project_name}-*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:ListTables"]
        Resource = ["*"]
      },
      # --- Lambda functions (5 handlers + aws_lambda_permission) ---
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction", "lambda:GetFunction",
          "lambda:GetFunctionConfiguration", "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration", "lambda:PublishVersion",
          "lambda:TagResource", "lambda:UntagResource",
          "lambda:AddPermission", "lambda:RemovePermission", "lambda:GetPolicy",
        ]
        Resource = ["arn:aws:lambda:*:*:function:${var.project_name}-*"]
      },
      {
        Effect   = "Allow"
        Action   = ["lambda:ListFunctions"]
        Resource = ["*"]
      },
      # --- IAM roles + inline policies (lambda roles, github roles) ---
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:GetRole", "iam:DeleteRole",
          "iam:AttachRolePolicy", "iam:DetachRolePolicy",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
          "iam:TagRole", "iam:UntagRole",
        ]
        Resource = ["arn:aws:iam::*:role/${var.project_name}-*"]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = ["arn:aws:iam::*:role/${var.project_name}-*"]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:TagPolicy"]
        Resource = ["arn:aws:iam::*:policy/${var.project_name}-*"]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:ListRoles"]
        Resource = ["*"]
      },
      # --- OIDC provider (aws_iam_openid_connect_provider.github, real AWS) ---
      {
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:GetOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
        ]
        Resource = ["arn:aws:iam::*:oidc-provider/token.actions.githubusercontent.com"]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:ListOpenIDConnectProviders"]
        Resource = ["*"]
      },
      # --- API Gateway (no resource-level ARNs for most resources; scoped to
      # the service with an explicit HTTP-verb action list) ---
      {
        Effect   = "Allow"
        Action   = ["apigateway:GET", "apigateway:POST", "apigateway:PUT", "apigateway:PATCH", "apigateway:DELETE"]
        Resource = ["arn:aws:apigateway:*::*"]
      },
      # --- CloudWatch Logs (API Gateway access-log group) ---
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup", "logs:UntagLogGroup", "logs:ListTagsLogGroup",
        ]
        Resource = ["arn:aws:logs:*:*:log-group:/aws/apigateway/${var.project_name}-*:*"]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = ["*"]
      },
      # --- CloudWatch metrics + dashboards (dashboard work is a later phase) ---
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData", "cloudwatch:GetMetricData"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutDashboard", "cloudwatch:GetDashboard", "cloudwatch:DeleteDashboards"]
        Resource = ["arn:aws:cloudwatch::*:dashboard/${var.project_name}-*"]
      },
      # --- Cognito (User Pool + client; create/list calls are global) ---
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPool", "cognito-idp:UpdateUserPool", "cognito-idp:DeleteUserPool",
          "cognito-idp:CreateUserPoolClient", "cognito-idp:DescribeUserPoolClient",
          "cognito-idp:UpdateUserPoolClient", "cognito-idp:DeleteUserPoolClient",
          "cognito-idp:ListUserPoolClients",
          "cognito-idp:TagResource", "cognito-idp:UntagResource", "cognito-idp:ListTagsForResource",
        ]
        Resource = ["arn:aws:cognito-idp:*:*:userpool/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:CreateUserPool", "cognito-idp:ListUserPools",
        ]
        Resource = ["*"]
      },
      # --- STS (needed by init/bootstrap paths) ---
      {
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = ["*"]
      },
    ]
  }
}

# IAM Role for GitHub Actions (zero-trust: no long-lived credentials)
# use_localstack=true trusts the local emulator account root (Floci has no OIDC);
# on real AWS the role is federated to GitHub via the OIDC provider, scoped by
# aud=sts.amazonaws.com and the branch-scoped sub patterns above.
resource "aws_iam_role" "github_actions" {
  for_each = local.github_actions_environments

  name = "${var.project_name}-github-actions-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
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
            "token.actions.githubusercontent.com:sub" = local.github_actions_sub_patterns[each.key]
          }
        }
      }
    ]
  })

  max_session_duration = 3600

  tags = {
    Project     = var.project_name
    Environment = each.key
  }

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Least-privilege permissions for Terraform deploys (dev and prod get the same
# policy: it is scoped to this stack's resources and its remote-state backend).
resource "aws_iam_role_policy" "github_actions_terraform" {
  for_each = aws_iam_role.github_actions

  name   = "terraform-deploy"
  role   = aws_iam_role.github_actions[each.key].id
  policy = jsonencode(local.github_actions_terraform_policy)
}
