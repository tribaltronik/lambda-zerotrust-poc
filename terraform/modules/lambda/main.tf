resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  filename         = var.zip_path
  source_code_hash = filebase64sha256(var.zip_path)
  role             = aws_iam_role.lambda_role.arn

  tracing_config {
    mode = var.tracing_mode
  }

  environment {
    variables = merge(
      var.environment_variables,
      {
        POWERTOOLS_SERVICE_NAME    = var.function_name
        LOG_LEVEL                  = "INFO"
        POWERTOOLS_METRICS_NAMESPACE = "LambdaZeroTrustPOC"
      }
    )
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags, tags_all, source_code_hash]
  }
}

# Least-privilege IAM role per function
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}

# Basic execution policy (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# X-Ray tracing policy
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Custom policy for function-specific permissions
resource "aws_iam_role_policy" "custom" {
  count = length(var.iam_policy_statements) > 0 ? 1 : 0
  name  = "${var.function_name}-custom"
  role  = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.iam_policy_statements
  })
}
