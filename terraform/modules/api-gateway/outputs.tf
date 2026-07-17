output "api_id" {
  value       = aws_api_gateway_rest_api.this.id
  description = "API Gateway REST API ID"
}

output "api_url" {
  value       = aws_api_gateway_stage.this.invoke_url
  description = "API Gateway stage invoke URL"
}

output "api_arn" {
  value       = aws_api_gateway_rest_api.this.arn
  description = "API Gateway REST API ARN"
}

output "stage_name" {
  value       = aws_api_gateway_stage.this.stage_name
  description = "API Gateway stage name"
}
