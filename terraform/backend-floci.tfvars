# Terraform S3 backend config for local Floci development.
# Pass with: terraform init -backend-config=terraform/backend-floci.tfvars
region         = "us-east-1"
bucket         = "lambda-zerotrust-poc-terraform-state"
key            = "lambda-zerotrust-poc/dev/terraform.tfstate"
dynamodb_table = "lambda-zerotrust-poc-terraform-locks"
encrypt        = true

skip_credentials_validation = true
skip_region_validation      = true
skip_requesting_account_id  = true
s3_use_path_style           = true

endpoints = {
  s3       = "http://localhost:4566"
  dynamodb = "http://localhost:4566"
}
