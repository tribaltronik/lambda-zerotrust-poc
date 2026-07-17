resource "aws_lambda_permission" "api_gateway" {
  for_each = {
    list_items  = module.lambda_list_items.function_name
    get_item    = module.lambda_get_item.function_name
    create_item = module.lambda_create_item.function_name
    update_item = module.lambda_update_item.function_name
    delete_item = module.lambda_delete_item.function_name
  }

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.api_arn}/*/*"
}
