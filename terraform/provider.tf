provider "aws" {
  region = var.aws_region

  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []
    content {
      s3             = var.aws_endpoint
      dynamodb       = var.aws_endpoint
      iam            = var.aws_endpoint
      sts            = var.aws_endpoint
      lambda         = var.aws_endpoint
      apigateway     = var.aws_endpoint
      apigatewayv2   = var.aws_endpoint
      ssm            = var.aws_endpoint
      secretsmanager = var.aws_endpoint
      logs           = var.aws_endpoint
      cloudwatch     = var.aws_endpoint
      cognitoidp     = var.aws_endpoint
    }
  }
}
