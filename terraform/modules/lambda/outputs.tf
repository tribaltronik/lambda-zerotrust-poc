output "function_name" {
  value       = aws_lambda_function.this.function_name
  description = "Lambda function name"
}

output "function_arn" {
  value       = aws_lambda_function.this.arn
  description = "Lambda function ARN"
}

output "invoke_arn" {
  value       = aws_lambda_function.this.invoke_arn
  description = "Lambda invoke ARN (for API Gateway)"
}

output "role_arn" {
  value       = aws_iam_role.lambda_role.arn
  description = "Lambda IAM role ARN"
}

output "role_name" {
  value       = aws_iam_role.lambda_role.name
  description = "Lambda IAM role name"
}
