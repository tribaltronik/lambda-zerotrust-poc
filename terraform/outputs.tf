output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN of the GitHub Actions IAM role"
}

output "oidc_provider_arn" {
  value       = var.use_localstack ? "N/A (Floci does not support OIDC providers)" : aws_iam_openid_connect_provider.github[0].arn
  description = "ARN of the GitHub OIDC provider (N/A when using Floci)"
}

output "terraform_state_bucket" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "Name of the S3 bucket for Terraform state"
}

output "terraform_lock_table" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "Name of the DynamoDB table for Terraform locks"
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
    list_items   = module.lambda_list_items.function_name
    get_item     = module.lambda_get_item.function_name
    create_item  = module.lambda_create_item.function_name
    update_item  = module.lambda_update_item.function_name
    delete_item  = module.lambda_delete_item.function_name
  }
  description = "Map of Lambda function names"
}

output "lambda_invoke_arns" {
  value = {
    list_items   = module.lambda_list_items.invoke_arn
    get_item     = module.lambda_get_item.invoke_arn
    create_item  = module.lambda_create_item.invoke_arn
    update_item  = module.lambda_update_item.invoke_arn
    delete_item  = module.lambda_delete_item.invoke_arn
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
