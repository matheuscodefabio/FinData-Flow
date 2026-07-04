# Dev: configuração de recursos reduzidos para economizar custo

environment = "dev"
aws_region  = "us-east-1"

# VPC
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# Lambda: reduzido em dev, sem Provisioned Concurrency
lambda_image_uri                = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/findata-ingestor:latest"
lambda_memory_size              = 256 # Reduzido
lambda_provisioned_concurrency  = 0   # Escala até zero em dev

# ECS: reduzido em dev
processor_image_uri = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/findata-processor:latest"
ecs_task_cpu        = 256  # Mínimo
ecs_task_memory     = 512  # Mínimo

# Secrets (usar Secrets Manager ou variáveis env na prática)
db_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:findata/rds-dev-XXXXX"
sns_alert_arn = "arn:aws:sns:us-east-1:ACCOUNT_ID:findata-alerts-dev"

# CloudFront: PriceClass_100 reduz custo
cloudfront_price_class = "PriceClass_100"
