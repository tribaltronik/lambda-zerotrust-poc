# CloudWatch dashboard for the PoC API.
# Skipped when targeting Floci: the local emulator does not implement CloudWatch
# dashboards, and keeping the resource out of the local apply keeps `make up`
# working. Same pattern as the OIDC provider in oidc.tf.
resource "aws_cloudwatch_dashboard" "main" {
  count = var.use_localstack ? 0 : 1

  # Must stay under the ${var.project_name}- prefix: the GitHub Actions
  # deploy-role policy (oidc.tf) scopes cloudwatch:PutDashboard to
  # arn:aws:cloudwatch::*:dashboard/${var.project_name}-*.
  dashboard_name = "${var.project_name}-dashboard"

  # The body references module outputs so it stays correct if names change.
  dashboard_body = jsonencode(local.dashboard_widgets)

  # Note: aws_cloudwatch_dashboard does not accept `tags` in the AWS provider,
  # so Project/Environment identification is carried by the dashboard_name
  # prefix instead of resource tags.
}

locals {
  # Function names come from the lambda module outputs, not hardcoded strings.
  dashboard_lambda_functions = [
    module.lambda_list_items.function_name,
    module.lambda_get_item.function_name,
    module.lambda_create_item.function_name,
    module.lambda_update_item.function_name,
    module.lambda_delete_item.function_name,
  ]

  # API Gateway name. The module (modules/api-gateway) does not expose the API
  # name as an output, so this mirrors the api_name passed in api-gateway.tf.
  # The stage name is taken from the module output (Environment tag = "dev").
  dashboard_api_name    = "${var.project_name}-api"
  dashboard_stage_name  = module.api_gateway.stage_name
  dashboard_table_name  = module.dynamodb.table_name

  # --- Metric series (CloudWatch "metrics" array form) -----------------------

  # Invocations per function (one multi-value metric widget for all 5).
  dashboard_lambda_invocations = [
    for fn in local.dashboard_lambda_functions : [
      "AWS/Lambda", "Invocations", "FunctionName", fn,
      { label = fn, stat = "Sum", period = 300 }
    ]
  ]

  # Errors + Throttles per function.
  dashboard_lambda_errors_throttles = flatten([
    for fn in local.dashboard_lambda_functions : [
      ["AWS/Lambda", "Errors", "FunctionName", fn, { label = "${fn} errors", stat = "Sum", period = 300 }],
      ["AWS/Lambda", "Throttles", "FunctionName", fn, { label = "${fn} throttles", stat = "Sum", period = 300 }],
    ]
  ])

  # Duration percentiles (p50/p95/p99) per function.
  dashboard_lambda_duration = flatten([
    for fn in local.dashboard_lambda_functions : [
      for stat in ["p50", "p95", "p99"] : [
        "AWS/Lambda", "Duration", "FunctionName", fn,
        { label = "${fn} ${stat}", stat = stat, period = 300, unit = "Milliseconds" }
      ]
    ]
  ])

  # API Gateway 4XX/5XX errors + latency.
  dashboard_api_errors = [
    ["AWS/ApiGateway", "4XXError", "ApiName", local.dashboard_api_name, "Stage", local.dashboard_stage_name, { label = "4XX errors", stat = "Sum", period = 300 }],
    ["AWS/ApiGateway", "5XXError", "ApiName", local.dashboard_api_name, "Stage", local.dashboard_stage_name, { label = "5XX errors", stat = "Sum", period = 300 }],
  ]

  dashboard_api_latency = [
    ["AWS/ApiGateway", "Latency", "ApiName", local.dashboard_api_name, "Stage", local.dashboard_stage_name, { label = "Latency p95", stat = "p95", period = 300, unit = "Milliseconds" }],
    ["AWS/ApiGateway", "IntegrationLatency", "ApiName", local.dashboard_api_name, "Stage", local.dashboard_stage_name, { label = "Integration latency p95", stat = "p95", period = 300, unit = "Milliseconds" }],
  ]

  # DynamoDB table errors / throttling.
  dashboard_dynamodb = [
    ["AWS/DynamoDB", "UserErrors", "TableName", local.dashboard_table_name, { label = "UserErrors", stat = "Sum", period = 300 }],
    ["AWS/DynamoDB", "ThrottledRequests", "TableName", local.dashboard_table_name, { label = "ThrottledRequests", stat = "Sum", period = 300 }],
  ]

  # --- Widget layout (24-column grid) ---------------------------------------

  dashboard_widgets = [
    {
      type = "text"
      x    = 0
      y    = 0
      width  = 24
      height = 2
      properties = {
        markdown = "# ${var.project_name} — ${var.environment}\n\nCRUD API observability: Lambda, API Gateway, DynamoDB. X-Ray is Active; cold-start init times are in the log widget below."
      }
    },
    {
      type = "metric"
      x    = 0
      y    = 2
      width  = 12
      height = 6
      properties = {
        metrics = local.dashboard_lambda_invocations
        view    = "timeSeries"
        region  = var.aws_region
        period  = 300
        stat    = "Sum"
        title   = "Lambda Invocations (per function)"
      }
    },
    {
      type = "metric"
      x    = 12
      y    = 2
      width  = 12
      height = 6
      properties = {
        metrics = local.dashboard_lambda_errors_throttles
        view    = "timeSeries"
        region  = var.aws_region
        period  = 300
        stat    = "Sum"
        title   = "Lambda Errors & Throttles"
      }
    },
    {
      type = "metric"
      x    = 0
      y    = 8
      width  = 12
      height = 6
      properties = {
        metrics = local.dashboard_lambda_duration
        view    = "timeSeries"
        region  = var.aws_region
        period  = 300
        stat    = "p50"
        title   = "Lambda Duration (p50 / p95 / p99)"
      }
    },
    {
      type = "metric"
      x    = 12
      y    = 8
      width  = 12
      height = 6
      properties = {
        metrics = local.dashboard_api_errors
        view    = "timeSeries"
        region  = var.aws_region
        period  = 300
        stat    = "Sum"
        title   = "API Gateway 4XX / 5XX errors"
      }
    },
    {
      type = "metric"
      x    = 0
      y    = 14
      width  = 12
      height = 6
      properties = {
        metrics = local.dashboard_api_latency
        view    = "timeSeries"
        region  = var.aws_region
        period  = 300
        stat    = "p95"
        title   = "API Gateway Latency (p95)"
      }
    },
    {
      type = "metric"
      x    = 12
      y    = 14
      width  = 12
      height = 6
      properties = {
        metrics = local.dashboard_dynamodb
        view    = "timeSeries"
        region  = var.aws_region
        period  = 300
        stat    = "Sum"
        title   = "DynamoDB UserErrors / ThrottledRequests"
      }
    },
    {
      # Informative-only: reports cold-start Init Duration from Lambda REPORT
      # lines. The init bucket is only present on the first (cold) call.
      type = "log"
      x    = 0
      y    = 20
      width  = 24
      height = 6
      properties = {
        query  = "fields @timestamp, @message | filter @message like /REPORT/ | parse @message /Init Duration: (?<initMs>[\\d.]+) ms/ | stats max(initMs) as maxInitMs, count() as coldStarts by @log | sort maxInitMs desc | limit 50"
        region = var.aws_region
        title  = "Cold starts — max Init Duration & count by function (informative)"
        view   = "table"
      }
    },
  ]
}
