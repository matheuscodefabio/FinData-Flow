resource "aws_lambda_function" "ingestor" {
  function_name = "findata-ingestor-${var.environment}"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  timeout       = 10
  memory_size   = var.memory_size

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      ENVIRONMENT    = var.environment
      SQS_QUEUE_URL  = var.sqs_queue_url
    }
  }

  tracing_config {
    mode = "Active" # X-Ray
  }

  tags = { Environment = var.environment }
}

# Provisioned Concurrency: elimina cold start em horário de pico
resource "aws_lambda_alias" "stable" {
  name             = "stable"
  function_name    = aws_lambda_function.ingestor.function_name
  function_version = aws_lambda_function.ingestor.version

  lifecycle {
    # Canary/rollback ajustam routing_config via AWS CLI durante o deploy.
    ignore_changes = [routing_config]
  }
}

resource "aws_lambda_provisioned_concurrency_config" "ingestor" {
  count                             = var.environment == "prod" ? 1 : 0
  function_name                     = aws_lambda_function.ingestor.function_name
  qualifier                         = aws_lambda_alias.stable.name
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
  integration_uri    = aws_lambda_alias.stable.invoke_arn
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

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Alarme: P99 latência
resource "aws_cloudwatch_metric_alarm" "p99_latency" {
  alarm_name          = "findata-lambda-p99-latency-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 130 # Alerta em 130ms, limite é 150ms
  alarm_actions       = [var.sns_alert_arn]

  dimensions = {
    FunctionName = aws_lambda_function.ingestor.function_name
    Resource     = "${aws_lambda_function.ingestor.function_name}:stable"
  }
}
