module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = "${var.project_name}-items"
  hash_key   = "PK"
  sort_key   = "SK"
  enable_ttl = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
