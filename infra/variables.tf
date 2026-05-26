variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project" {
  description = "Project name for tagging"
  type        = string
  default     = "msp-monitoring"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email address for alarm notifications"
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "alarms" {
  description = "Map of CloudWatch alarm definitions"
  type = map(object({
    namespace           = string
    metric_name         = string
    statistic           = string
    comparison_operator = string
    threshold           = number
    period              = number
    evaluation_periods  = number
    datapoints_to_alarm = number
    treat_missing_data  = string
    severity            = string
    dimensions          = map(string)
    description         = string
  }))

  validation {
    condition     = alltrue([for alarm in values(var.alarms) : contains(["P1", "P2", "P3", "P4"], alarm.severity)])
    error_message = "Each alarm severity must be one of P1, P2, P3, or P4."
  }

  validation {
    condition     = alltrue([for alarm in values(var.alarms) : contains(["breaching", "notBreaching", "ignore", "missing"], alarm.treat_missing_data)])
    error_message = "Each alarm treat_missing_data must be one of breaching, notBreaching, ignore, or missing."
  }
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for runbook diagnostics"
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "ECS service name for runbook diagnostics"
  type        = string
  default     = ""
}

variable "app_log_group_name" {
  description = "CloudWatch Log Group for application logs"
  type        = string
  default     = ""
}

variable "target_group_arn" {
  description = "ALB Target Group ARN for health checks"
  type        = string
  default     = ""
}

variable "runbook_log_level" {
  description = "Runbook Lambda log level (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for runbook notifications (optional)"
  type        = string
  default     = ""
  sensitive   = true
}
