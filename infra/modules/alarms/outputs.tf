output "alarm_names" {
  description = "List of all CloudWatch alarm names"
  value       = [for k, v in aws_cloudwatch_metric_alarm.this : v.alarm_name]
}

output "alarm_arns" {
  description = "Map of alarm key to alarm ARN"
  value       = { for k, v in aws_cloudwatch_metric_alarm.this : k => v.arn }
}
