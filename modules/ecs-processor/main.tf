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
      { name = "SQS_QUEUE_URL", value = var.sqs_queue_url }
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
