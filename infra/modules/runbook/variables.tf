variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "sns_topic_arn_p1p2" {
  description = "SNS topic ARN that triggers the runbook engine"
  type        = string
}

variable "notification_topic_arn" {
  description = "SNS topic ARN where diagnosis results are published"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for diagnostics"
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "ECS service name for diagnostics"
  type        = string
  default     = ""
}

variable "app_log_group_name" {
  description = "CloudWatch Log Group name for application logs"
  type        = string
  default     = ""
}

variable "target_group_arn" {
  description = "ALB Target Group ARN for health checks"
  type        = string
  default     = ""
}

variable "log_level" {
  description = "Lambda log level"
  type        = string
  default     = "INFO"
}
