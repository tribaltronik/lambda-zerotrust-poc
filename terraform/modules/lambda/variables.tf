variable "function_name" {
  type        = string
  description = "Lambda function name"
}

variable "handler" {
  type        = string
  default     = "handler.lambda_handler"
  description = "Lambda handler function"
}

variable "runtime" {
  type        = string
  default     = "python3.13"
  description = "Lambda runtime"
}

variable "timeout" {
  type        = number
  default     = 10
  description = "Lambda timeout in seconds"
}

variable "memory_size" {
  type        = number
  default     = 256
  description = "Lambda memory in MB"
}

variable "zip_path" {
  type        = string
  description = "Path to pre-built Lambda zip package"
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Lambda environment variables"
}

variable "tracing_mode" {
  type        = string
  default     = "Active"
  description = "X-Ray tracing mode (Active/PassThrough)"
}

variable "iam_policy_statements" {
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = list(string)
  }))
  default     = []
  description = "Additional IAM policy statements for this function"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Resource tags"
}
