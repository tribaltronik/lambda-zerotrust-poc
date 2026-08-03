output "github_actions_role_arn" {
  value       = { for k, r in aws_iam_role.github_actions : k => r.arn }
  description = "Map of environment (dev, prod) to the ARN of its GitHub Actions IAM role"
}

output "github_actions_dev_role_arn" {
  value       = aws_iam_role.github_actions["dev"].arn
  description = "ARN of the dev GitHub Actions IAM role (repo-level AWS_ROLE_ARN variable)"
}

output "oidc_provider_arn" {
  value       = var.use_localstack ? "N/A (Floci does not support OIDC providers)" : aws_iam_openid_connect_provider.github[0].arn
  description = "ARN of the GitHub OIDC provider (N/A when using Floci)"
}

output "dynamodb_table_name" {
  value       = module.dynamodb.table_name
  description = "DynamoDB items table name"
}

output "dynamodb_table_arn" {
  value       = module.dynamodb.table_arn
  description = "DynamoDB items table ARN"
}

output "lambda_functions" {
  value = {
    list_items  = module.lambda_list_items.function_name
    get_item    = module.lambda_get_item.function_name
    create_item = module.lambda_create_item.function_name
    update_item = module.lambda_update_item.function_name
    delete_item = module.lambda_delete_item.function_name
  }
  description = "Map of Lambda function names"
}

output "lambda_invoke_arns" {
  value = {
    list_items  = module.lambda_list_items.invoke_arn
    get_item    = module.lambda_get_item.invoke_arn
    create_item = module.lambda_create_item.invoke_arn
    update_item = module.lambda_update_item.invoke_arn
    delete_item = module.lambda_delete_item.invoke_arn
  }
  description = "Map of Lambda invoke ARNs"
}

output "api_url" {
  value       = module.api_gateway.api_url
  description = "API Gateway invoke URL"
}

output "api_id" {
  value       = module.api_gateway.api_id
  description = "API Gateway REST API ID"
}

output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.main.id
  description = "Cognito User Pool ID"
}

output "cognito_user_pool_client_id" {
  value       = aws_cognito_user_pool_client.main.id
  description = "Cognito User Pool Client ID"
}
