terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "../../modules/networking"

  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "sqs" {
  source = "../../modules/sqs"

  environment   = var.environment
  sns_alert_arn = var.sns_alert_arn
}

module "dynamodb_state" {
  source = "../../modules/dynamodb-state"

  environment = var.environment
}

module "lambda_ingestor" {
  source = "../../modules/lambda-ingestor"

  environment             = var.environment
  image_uri               = var.lambda_image_uri
  memory_size             = var.lambda_memory_size
  provisioned_concurrency = var.lambda_provisioned_concurrency
  subnet_ids              = module.networking.private_subnet_ids
  security_group_id       = module.networking.sg_lambda_id
  sqs_queue_url           = module.sqs.queue_url
  sqs_queue_arn           = module.sqs.queue_arn
  db_state_table_arn      = module.dynamodb_state.table_arn
  db_state_table_name     = module.dynamodb_state.table_name
  sns_alert_arn           = var.sns_alert_arn
  enable_canary           = var.enable_canary
}

module "ecs_processor" {
  source = "../../modules/ecs-processor"

  environment         = var.environment
  image_uri           = var.processor_image_uri
  task_cpu            = var.ecs_task_cpu
  task_memory         = var.ecs_task_memory
  subnet_ids          = module.networking.private_subnet_ids
  security_group_id   = module.networking.sg_ecs_processor_id
  sqs_queue_url       = module.sqs.queue_url
  sqs_queue_arn       = module.sqs.queue_arn
  sqs_queue_name      = module.sqs.queue_name
  db_secret_arn       = var.db_secret_arn
  db_state_table_arn  = module.dynamodb_state.table_arn
  db_state_table_name = module.dynamodb_state.table_name
  desired_count       = var.ecs_desired_count
  min_tasks           = var.ecs_min_tasks
  max_tasks           = var.ecs_max_tasks
  messages_per_task   = var.ecs_messages_per_task
  aws_region          = var.aws_region
}

module "frontend" {
  source = "../../modules/frontend"

  environment            = var.environment
  cloudfront_price_class = var.cloudfront_price_class
}
