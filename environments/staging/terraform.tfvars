# Staging: configuração intermediária, próxima de prod

environment = "staging"
aws_region  = "us-east-1"

# VPC
vpc_cidr             = "10.1.0.0/16"
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# Lambda: paridade com prod, mas sem Provisioned Concurrency
# valor real injetado pelo pipeline via -var (vars do GitHub); nunca usar tag mutavel
lambda_image_uri               = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/findata-ingestor@sha256:REPLACE_WITH_DIGEST"
lambda_memory_size             = 512 # Igual a prod
lambda_provisioned_concurrency = 5   # Metade de prod para validar comportamento

# ECS: paridade com prod
processor_image_uri   = "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/findata-processor@sha256:REPLACE_WITH_DIGEST"
ecs_task_cpu          = 1024 # Igual a prod
ecs_task_memory       = 2048 # Igual a prod
ecs_desired_count     = 1
ecs_min_tasks         = 1
ecs_max_tasks         = 8
ecs_messages_per_task = 10

# Secrets
db_secret_arn = "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:findata/rds-staging-XXXXX"
sns_alert_arn = "arn:aws:sns:us-east-1:ACCOUNT_ID:findata-alerts-staging"

# CloudFront: igual a prod para testes realistas
cloudfront_price_class = "PriceClass_100"
