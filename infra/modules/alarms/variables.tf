variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
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

variable "sns_topic_arn_p1p2" {
  description = "SNS topic ARN for P1/P2 severity alarms"
  type        = string
}

variable "sns_topic_arn_p3p4" {
  description = "SNS topic ARN for P3/P4 severity alarms"
  type        = string
}
