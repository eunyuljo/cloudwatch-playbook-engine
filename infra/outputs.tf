output "sns_topic_arn_p1p2" {
  description = "SNS topic ARN for P1/P2 alerts"
  value       = module.sns.topic_arn_p1p2
}

output "sns_topic_arn_p3p4" {
  description = "SNS topic ARN for P3/P4 alerts"
  value       = module.sns.topic_arn_p3p4
}

output "alarm_names" {
  description = "List of all CloudWatch alarm names created"
  value       = module.alarms.alarm_names
}

output "alarm_arns" {
  description = "Map of alarm key to alarm ARN"
  value       = module.alarms.alarm_arns
}
