resource "aws_sqs_queue" "dlq" {
  name                      = "findata-processor-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 dias

  tags = { Environment = var.environment }
}

resource "aws_sqs_queue" "processor" {
  name                       = "findata-processor-${var.environment}"
  visibility_timeout_seconds = 2700  # 45 minutos (> max batch de 40min)
  message_retention_seconds  = 86400 # 24 horas

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Environment = var.environment }
}

# Alarme: mensagens na DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "findata-dlq-not-empty-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Mensagens na DLQ — investigar falhas de processamento"
  alarm_actions       = [var.sns_alert_arn]

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}
