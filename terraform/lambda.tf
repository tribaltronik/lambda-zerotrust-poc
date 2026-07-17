locals {
  lambda_common_env = {
    DYNAMODB_TABLE_NAME = module.dynamodb.table_name
    AWS_REGION          = var.aws_region
  }

  lambda_build_dir = "${path.module}/../.build/lambdas"
}

module "lambda_list_items" {
  source = "./modules/lambda"

  function_name = "${var.project_name}-list-items"
  zip_path      = "${local.lambda_build_dir}/list_items.zip"
  handler       = "list_items.lambda_handler"
  environment_variables = local.lambda_common_env

  iam_policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["dynamodb:Scan", "dynamodb:Query"]
      Resource = [module.dynamodb.table_arn]
    }
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "lambda_get_item" {
  source = "./modules/lambda"

  function_name = "${var.project_name}-get-item"
  zip_path      = "${local.lambda_build_dir}/get_item.zip"
  handler       = "get_item.lambda_handler"
  environment_variables = local.lambda_common_env

  iam_policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem"]
      Resource = [module.dynamodb.table_arn]
    }
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "lambda_create_item" {
  source = "./modules/lambda"

  function_name = "${var.project_name}-create-item"
  zip_path      = "${local.lambda_build_dir}/create_item.zip"
  handler       = "create_item.lambda_handler"
  environment_variables = local.lambda_common_env

  iam_policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = [module.dynamodb.table_arn]
    }
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "lambda_update_item" {
  source = "./modules/lambda"

  function_name = "${var.project_name}-update-item"
  zip_path      = "${local.lambda_build_dir}/update_item.zip"
  handler       = "update_item.lambda_handler"
  environment_variables = local.lambda_common_env

  iam_policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem"]
      Resource = [module.dynamodb.table_arn]
    }
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "lambda_delete_item" {
  source = "./modules/lambda"

  function_name = "${var.project_name}-delete-item"
  zip_path      = "${local.lambda_build_dir}/delete_item.zip"
  handler       = "delete_item.lambda_handler"
  environment_variables = local.lambda_common_env

  iam_policy_statements = [
    {
      Effect   = "Allow"
      Action   = ["dynamodb:DeleteItem"]
      Resource = [module.dynamodb.table_arn]
    }
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
