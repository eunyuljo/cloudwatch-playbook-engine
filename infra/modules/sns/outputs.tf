output "topic_arn_p1p2" {
  description = "ARN of the P1/P2 SNS topic"
  value       = aws_sns_topic.p1p2.arn
}

output "topic_arn_p3p4" {
  description = "ARN of the P3/P4 SNS topic"
  value       = aws_sns_topic.p3p4.arn
}
