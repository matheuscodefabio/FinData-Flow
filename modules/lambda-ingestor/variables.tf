variable "environment" {
	type = string
}

variable "image_uri" {
	type = string
}

variable "memory_size" {
	type    = number
	default = 512
}

variable "provisioned_concurrency" {
	type    = number
	default = 5
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

variable "sns_alert_arn" {
	type = string
}
