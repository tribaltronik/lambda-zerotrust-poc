variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "project_name" {
  type        = string
  default     = "lambda-zerotrust-poc"
  description = "Project name used for resource naming"
}

variable "state_bucket_name" {
  type        = string
  default     = "lambda-zerotrust-poc-terraform-state"
  description = "Name of the S3 bucket holding Terraform state"
}

variable "lock_table_name" {
  type        = string
  default     = "lambda-zerotrust-poc-terraform-locks"
  description = "Name of the DynamoDB table used for state locking"
}

variable "aws_endpoint" {
  type        = string
  default     = "http://localhost:4566"
  description = "AWS endpoint URL (Floci for local, null for real AWS)"
}

variable "use_localstack" {
  type        = bool
  default     = true
  description = "Whether to use local emulator endpoint"
}
