resource "aws_lambda_function" "ingestor" {
  function_name = "findata-ingestor-${var.environment}"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  publish       = true
  timeout       = 10
  memory_size   = var.memory_size

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      ENVIRONMENT         = var.environment
      SQS_QUEUE_URL       = var.sqs_queue_url
      DB_STATE_TABLE_NAME = var.db_state_table_name
    }
  }

  tracing_config {
    mode = "Active" # X-Ray
  }

  tags = { Environment = var.environment }
}

resource "aws_lambda_alias" "stable_direct" {
  count            = var.enable_canary ? 0 : 1
  name             = "stable"
  function_name    = aws_lambda_function.ingestor.function_name
  function_version = aws_lambda_function.ingestor.version
}

resource "aws_lambda_alias" "stable_codedeploy" {
  count            = var.enable_canary ? 1 : 0
  name             = "stable"
  function_name    = aws_lambda_function.ingestor.function_name
  function_version = aws_lambda_function.ingestor.version

  lifecycle {
    # Em prod, o CodeDeploy controla o shift de trafego e a promocao do alias.
    ignore_changes = [function_version, routing_config]
  }
}

locals {
  stable_alias_name       = var.enable_canary ? aws_lambda_alias.stable_codedeploy[0].name : aws_lambda_alias.stable_direct[0].name
  stable_alias_arn        = var.enable_canary ? aws_lambda_alias.stable_codedeploy[0].arn : aws_lambda_alias.stable_direct[0].arn
  stable_alias_invoke_arn = var.enable_canary ? aws_lambda_alias.stable_codedeploy[0].invoke_arn : aws_lambda_alias.stable_direct[0].invoke_arn
}

# Provisioned Concurrency reduz cold start para a versao principal do alias.
resource "aws_lambda_provisioned_concurrency_config" "ingestor" {
  count                             = var.environment == "prod" ? 1 : 0
  function_name                     = aws_lambda_function.ingestor.function_name
  qualifier                         = local.stable_alias_name
  provisioned_concurrent_executions = var.provisioned_concurrency
}

# API Gateway
resource "aws_apigatewayv2_api" "ingestor" {
  name          = "findata-ingestor-${var.environment}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.ingestor.id
  integration_type   = "AWS_PROXY"
  integration_uri    = local.stable_alias_invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "ingest" {
  api_id    = aws_apigatewayv2_api.ingestor.id
  route_key = "POST /ingest"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.ingestor.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_invoke_alias" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestor.function_name
  qualifier     = local.stable_alias_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ingestor.execution_arn}/*/*"
}

resource "aws_iam_role" "lambda" {
  name = "findata-lambda-ingestor-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_sqs" {
  name = "sqs-send"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = [var.sqs_queue_arn]
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb_state" {
  name = "dynamodb-state"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ]
      Resource = [var.db_state_table_arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role" "codedeploy" {
  count = var.enable_canary ? 1 : 0
  name  = "findata-codedeploy-lambda-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_lambda" {
  count      = var.enable_canary ? 1 : 0
  role       = aws_iam_role.codedeploy[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRoleForLambda"
}

resource "aws_cloudwatch_metric_alarm" "canary_p99_latency" {
  count               = var.enable_canary ? 1 : 0
  alarm_name          = "findata-lambda-canary-p99-latency-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 130
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_alert_arn]

  # O alarme acompanha a ultima versao publicada no apply atual.
  # Se houver rollback manual para versao antiga, a dimensao sera alinhada no proximo apply.

  metric_query {
    id          = "p99_duration"
    return_data = true

    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Duration"
      period      = 60
      stat        = "p99"
      dimensions = {
        FunctionName    = aws_lambda_function.ingestor.function_name
        ExecutedVersion = aws_lambda_function.ingestor.version
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "canary_error_rate" {
  count               = var.enable_canary ? 1 : 0
  alarm_name          = "findata-lambda-canary-error-rate-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 0.02
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_alert_arn]

  # O alarme acompanha a ultima versao publicada no apply atual.
  # Se houver rollback manual para versao antiga, a dimensao sera alinhada no proximo apply.

  metric_query {
    id          = "m_errors"
    return_data = false

    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      period      = 60
      stat        = "Sum"
      dimensions = {
        FunctionName    = aws_lambda_function.ingestor.function_name
        ExecutedVersion = aws_lambda_function.ingestor.version
      }
    }
  }

  metric_query {
    id          = "m_invocations"
    return_data = false

    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Invocations"
      period      = 60
      stat        = "Sum"
      dimensions = {
        FunctionName    = aws_lambda_function.ingestor.function_name
        ExecutedVersion = aws_lambda_function.ingestor.version
      }
    }
  }

  metric_query {
    id          = "e_error_rate"
    expression  = "IF(m_invocations>0,m_errors/m_invocations,0)"
    label       = "Lambda canary error rate"
    return_data = true
  }
}

resource "aws_codedeploy_app" "lambda" {
  count            = var.enable_canary ? 1 : 0
  name             = "findata-lambda-${var.environment}"
  compute_platform = "Lambda"
}

resource "aws_codedeploy_deployment_group" "lambda" {
  count                  = var.enable_canary ? 1 : 0
  app_name               = aws_codedeploy_app.lambda[0].name
  deployment_group_name  = "findata-lambda-dg-${var.environment}"
  service_role_arn       = aws_iam_role.codedeploy[0].arn
  deployment_config_name = "CodeDeployDefault.LambdaCanary10Percent15Minutes"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  alarm_configuration {
    enabled = true
    alarms = [
      aws_cloudwatch_metric_alarm.canary_p99_latency[0].alarm_name,
      aws_cloudwatch_metric_alarm.canary_error_rate[0].alarm_name
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.codedeploy_lambda]
}
