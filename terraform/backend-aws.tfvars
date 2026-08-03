# Terraform S3 backend config for real AWS (GitHub Actions / manual).
# Pass with: terraform init -backend-config=terraform/backend-aws.tfvars
region         = "us-east-1"
bucket         = "lambda-zerotrust-poc-terraform-state"
key            = "lambda-zerotrust-poc/dev/terraform.tfstate"
dynamodb_table = "lambda-zerotrust-poc-terraform-locks"
encrypt        = true
