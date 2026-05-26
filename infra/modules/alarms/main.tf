locals {
  service_by_namespace = {
    "AWS/CloudFront"     = "CloudFront"
    "AWS/WAFV2"          = "WAF"
    "AWS/ApplicationELB" = "ALB"
    "AWS/ECS"            = "ECS"
    "AWS/RDS"            = "Aurora"
    "AWS/Lambda"         = "Lambda"
    "AWS/S3"             = "S3"
    "CloudTrailMetrics"  = "CloudTrail"
  }
}


resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.alarms

  alarm_name          = "${var.project}-${var.environment}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  statistic           = each.value.statistic
  comparison_operator = each.value.comparison_operator
  threshold           = each.value.threshold
  period              = each.value.period
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  treat_missing_data  = each.value.treat_missing_data

  dimensions = each.value.dimensions

  alarm_actions             = contains(["P1", "P2"], each.value.severity) ? [var.sns_topic_arn_p1p2] : [var.sns_topic_arn_p3p4]
  ok_actions                = contains(["P1", "P2"], each.value.severity) ? [var.sns_topic_arn_p1p2] : [var.sns_topic_arn_p3p4]
  insufficient_data_actions = contains(["P1", "P2"], each.value.severity) ? [var.sns_topic_arn_p1p2] : [var.sns_topic_arn_p3p4]

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = lookup(local.service_by_namespace, each.value.namespace, each.value.namespace)
    Severity    = each.value.severity
  }
}
