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

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name (dev, staging, prod)"
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

variable "github_org" {
  type        = string
  description = "GitHub organization or username"
}

variable "github_repo" {
  type        = string
  default     = "lambda-zerotrust-poc"
  description = "GitHub repository name"
}
