# Production: configuração escalável com redundância Multi-AZ

environment = "prod"
aws_region  = "us-east-1"

# VPC
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# Lambda: alto desempenho com Provisioned Concurrency
lambda_image_uri                = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/findata-ingestor:latest"
lambda_memory_size              = 512
lambda_provisioned_concurrency  = 10

# ECS: recursos máximos para processamento heavy
processor_image_uri = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/findata-processor:latest"
ecs_task_cpu        = 1024
ecs_task_memory     = 2048

# Secrets
db_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:findata/rds-prod-XXXXX"
sns_alert_arn = "arn:aws:sns:us-east-1:ACCOUNT_ID:findata-alerts-prod"

# CloudFront: PriceClass_All para distribuição global
cloudfront_price_class = "PriceClass_All"
