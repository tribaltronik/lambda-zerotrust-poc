# REST API
resource "aws_api_gateway_rest_api" "this" {
  name = var.api_name

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "${var.api_name}-cognito"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# Resources and methods for each route
resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "items"
}

resource "aws_api_gateway_resource" "item" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.items.id
  path_part   = "{id}"
}

# Local for route configs
locals {
  routes = {
    list_items = {
      http_method = "GET"
      resource_id = aws_api_gateway_resource.items.id
    }
    get_item = {
      http_method = "GET"
      resource_id = aws_api_gateway_resource.item.id
    }
    create_item = {
      http_method = "POST"
      resource_id = aws_api_gateway_resource.items.id
    }
    update_item = {
      http_method = "PUT"
      resource_id = aws_api_gateway_resource.item.id
    }
    delete_item = {
      http_method = "DELETE"
      resource_id = aws_api_gateway_resource.item.id
    }
  }
}

# API Gateway methods
resource "aws_api_gateway_method" "this" {
  for_each = local.routes

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = each.value.resource_id
  http_method   = each.value.http_method
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# Lambda proxy integration
resource "aws_api_gateway_integration" "this" {
  for_each = var.routes

  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_method.this[each.key].resource_id
  http_method             = aws_api_gateway_method.this[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.invoke_arn
}

# Deployment
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  depends_on = [
    aws_api_gateway_integration.this,
  ]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.items.id,
      aws_api_gateway_resource.item.id,
      [for r in aws_api_gateway_method.this : r.id],
      [for i in aws_api_gateway_integration.this : i.id],
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.tags["Environment"] != null ? var.tags["Environment"] : "dev"

  tags = var.tags

  lifecycle {
    ignore_changes = [tags, tags_all]
  }
}
