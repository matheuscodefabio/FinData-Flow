# Região AWS
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Ambiente
variable "environment" {
  type = string
}

# VPC e Networking
variable "vpc_cidr" {
  type = string
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

# Lambda Ingestor
variable "lambda_image_uri" {
  type        = string
  description = "URI da imagem Docker no ECR para Lambda"
}

variable "lambda_memory_size" {
  type        = number
  description = "Memória em MB para Lambda"
  default     = 512
}

variable "lambda_provisioned_concurrency" {
  type        = number
  description = "Concorrência provisionada (0 em dev, >0 em prod)"
  default     = 0
}

# ECS Processor
variable "processor_image_uri" {
  type        = string
  description = "URI da imagem Docker no ECR para ECS"
}

variable "ecs_task_cpu" {
  type        = number
  description = "CPU em unidades Fargate (256, 512, 1024, 2048, 4096)"
  default     = 1024
}

variable "ecs_task_memory" {
  type        = number
  description = "Memória em MB para tarefa ECS"
  default     = 2048
}

# RDS e Secrets
variable "db_secret_arn" {
  type        = string
  description = "ARN do secret do RDS no Secrets Manager"
}

# SNS e Alertas
variable "sns_alert_arn" {
  type        = string
  description = "ARN do tópico SNS para alertas"
}

# CloudFront
variable "cloudfront_price_class" {
  type        = string
  description = "Classe de preço CloudFront"
  default     = "PriceClass_100"
}
