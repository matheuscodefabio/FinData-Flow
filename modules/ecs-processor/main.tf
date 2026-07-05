resource "aws_ecs_cluster" "processor" {
  name = "findata-processor-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "processor" {
  family                   = "findata-processor-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "processor"
    image     = var.image_uri
    essential = true

    environment = [
      { name = "ENVIRONMENT", value = var.environment },
      { name = "SQS_QUEUE_URL", value = var.sqs_queue_url },
      { name = "DB_STATE_TABLE_NAME", value = var.db_state_table_name }
    ]

    secrets = [
      { name = "DB_PASSWORD", valueFrom = var.db_secret_arn }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/findata-processor-${var.environment}"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "processor"
      }
    }
  }])
}

resource "aws_cloudwatch_log_group" "processor" {
  name              = "/ecs/findata-processor-${var.environment}"
  retention_in_days = 30
}

# IAM: Execution Role (pull ECR, push logs)
resource "aws_iam_role" "ecs_execution" {
  name = "findata-ecs-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "secretsmanager-read-db-password"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.db_secret_arn]
    }]
  })
}

# IAM: Task Role (permissões da aplicação)
resource "aws_iam_role" "ecs_task" {
  name = "findata-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_sqs" {
  name = "sqs-consume"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = [var.sqs_queue_arn]
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_dynamodb_state" {
  name = "dynamodb-state-access"
  role = aws_iam_role.ecs_task.id

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

resource "aws_ecs_service" "processor" {
  name            = "findata-processor-${var.environment}"
  cluster         = aws_ecs_cluster.processor.id
  task_definition = aws_ecs_task_definition.processor.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false
  }

  depends_on = [
    aws_cloudwatch_log_group.processor,
    aws_iam_role_policy_attachment.ecs_execution,
    aws_iam_role_policy.ecs_execution_secrets
  ]
}

resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = var.max_tasks
  min_capacity       = var.min_tasks
  resource_id        = "service/${aws_ecs_cluster.processor.name}/${aws_ecs_service.processor.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_queue_depth" {
  name               = "findata-ecs-queue-depth-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.messages_per_task
    scale_in_cooldown  = 120
    scale_out_cooldown = 60

    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      dimensions {
        name  = "QueueName"
        value = var.sqs_queue_name
      }
    }
  }
}
