variable "api_name" {
  type        = string
  description = "API Gateway REST API name"
}

variable "cognito_user_pool_arn" {
  type        = string
  description = "Cognito User Pool ARN for authorizer"
}

variable "routes" {
  type = map(object({
    http_method = string
    path        = string
    invoke_arn  = string
  }))
  description = "Map of routes to Lambda invoke ARNs"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
