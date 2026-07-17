module "api_gateway" {
  source = "./modules/api-gateway"

  api_name              = "${var.project_name}-api"
  cognito_user_pool_arn = aws_cognito_user_pool.main.arn

  routes = {
    list_items = {
      http_method = "GET"
      path        = "/items"
      invoke_arn  = module.lambda_list_items.invoke_arn
    }
    get_item = {
      http_method = "GET"
      path        = "/items/{id}"
      invoke_arn  = module.lambda_get_item.invoke_arn
    }
    create_item = {
      http_method = "POST"
      path        = "/items"
      invoke_arn  = module.lambda_create_item.invoke_arn
    }
    update_item = {
      http_method = "PUT"
      path        = "/items/{id}"
      invoke_arn  = module.lambda_update_item.invoke_arn
    }
    delete_item = {
      http_method = "DELETE"
      path        = "/items/{id}"
      invoke_arn  = module.lambda_delete_item.invoke_arn
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
