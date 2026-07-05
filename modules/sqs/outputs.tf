output "queue_url" { value = aws_sqs_queue.processor.url }
output "queue_arn" { value = aws_sqs_queue.processor.arn }
output "queue_name" { value = aws_sqs_queue.processor.name }
output "dlq_arn" { value = aws_sqs_queue.dlq.arn }
