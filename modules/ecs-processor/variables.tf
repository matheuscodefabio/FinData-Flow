variable "environment" {
  type = string
}

variable "image_uri" {
  type = string
}

variable "task_cpu" {
  type    = number
  default = 1024
}

variable "task_memory" {
  type    = number
  default = 2048
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "sqs_queue_url" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "sqs_queue_name" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "db_state_table_arn" {
  type = string
}

variable "db_state_table_name" {
  type = string
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "min_tasks" {
  type    = number
  default = 1
}

variable "max_tasks" {
  type    = number
  default = 10
}

variable "messages_per_task" {
  type    = number
  default = 10
}

variable "aws_region" {
  type = string
}
