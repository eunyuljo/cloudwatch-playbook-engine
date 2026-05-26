alarms = {
  cloudfront_5xx = {
    namespace           = "AWS/CloudFront"
    metric_name         = "5xxErrorRate"
    statistic           = "Average"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 5
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 2
    treat_missing_data  = "notBreaching"
    severity            = "P1"
    dimensions = {
      DistributionId = "CHANGE_ME"
      Region         = "Global"
    }
    description = "CloudFront 5xx error rate exceeded 5%. Playbook: cloudfront-5xx.md"
  }

  cloudfront_origin_latency = {
    namespace           = "AWS/CloudFront"
    metric_name         = "OriginLatency"
    statistic           = "Average"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 2000
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 2
    treat_missing_data  = "notBreaching"
    severity            = "P3"
    dimensions = {
      DistributionId = "CHANGE_ME"
      Region         = "Global"
    }
    description = "CloudFront origin latency exceeded 2s baseline. Playbook: cloudfront-origin-latency.md"
  }

  waf_blocked_spike = {
    namespace           = "AWS/WAFV2"
    metric_name         = "BlockedRequests"
    statistic           = "Sum"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 1000
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 2
    treat_missing_data  = "notBreaching"
    severity            = "P3"
    dimensions = {
      WebACLName = "CHANGE_ME"
      Rule       = "ALL"
      Region     = "ap-northeast-2"
    }
    description = "WAF blocked requests spike (3x normal). Playbook: waf-block-spike.md"
  }

  alb_elb_5xx = {
    namespace           = "AWS/ApplicationELB"
    metric_name         = "HTTPCode_ELB_5XX_Count"
    statistic           = "Sum"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 10
    period              = 300
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "notBreaching"
    severity            = "P1"
    dimensions = {
      LoadBalancer = "CHANGE_ME"
    }
    description = "ALB-level 5xx count exceeded 10 in 5 min. Playbook: alb-elb-5xx.md"
  }

  alb_target_5xx = {
    namespace           = "AWS/ApplicationELB"
    metric_name         = "HTTPCode_Target_5XX_Count"
    statistic           = "Sum"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 50
    period              = 300
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "notBreaching"
    severity            = "P2"
    dimensions = {
      LoadBalancer = "CHANGE_ME"
      TargetGroup  = "CHANGE_ME"
    }
    description = "ALB target 5xx count exceeded 50 in 5 min. Playbook: alb-target-5xx.md"
  }

  alb_unhealthy_host = {
    namespace           = "AWS/ApplicationELB"
    metric_name         = "UnHealthyHostCount"
    statistic           = "Maximum"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    threshold           = 1
    period              = 300
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "breaching"
    severity            = "P1"
    dimensions = {
      LoadBalancer = "CHANGE_ME"
      TargetGroup  = "CHANGE_ME"
    }
    description = "ALB unhealthy host detected. Playbook: alb-unhealthy-host.md"
  }

  ecs_running_task_low = {
    namespace           = "AWS/ECS"
    metric_name         = "RunningTaskCount"
    statistic           = "Minimum"
    comparison_operator = "LessThanThreshold"
    threshold           = 2
    period              = 300
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "breaching"
    severity            = "P1"
    dimensions = {
      ClusterName = "CHANGE_ME"
      ServiceName = "CHANGE_ME"
    }
    description = "ECS running task count below desired. Playbook: ecs-task-count-low.md"
  }

  ecs_cpu_high = {
    namespace           = "AWS/ECS"
    metric_name         = "CPUUtilization"
    statistic           = "Average"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 80
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 3
    treat_missing_data  = "notBreaching"
    severity            = "P3"
    dimensions = {
      ClusterName = "CHANGE_ME"
      ServiceName = "CHANGE_ME"
    }
    description = "ECS CPU utilization exceeded 80% for 15 min. Playbook: ecs-cpu-high.md"
  }

  ecs_memory_high = {
    namespace           = "AWS/ECS"
    metric_name         = "MemoryUtilization"
    statistic           = "Average"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 85
    period              = 300
    evaluation_periods  = 2
    datapoints_to_alarm = 2
    treat_missing_data  = "notBreaching"
    severity            = "P2"
    dimensions = {
      ClusterName = "CHANGE_ME"
      ServiceName = "CHANGE_ME"
    }
    description = "ECS memory utilization exceeded 85% for 10 min. Playbook: ecs-memory-high.md"
  }

  aurora_connections_high = {
    namespace           = "AWS/RDS"
    metric_name         = "DatabaseConnections"
    statistic           = "Average"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 800
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 2
    treat_missing_data  = "notBreaching"
    severity            = "P2"
    dimensions = {
      DBClusterIdentifier = "CHANGE_ME"
    }
    description = "Aurora DB connections exceeded 80% of max. Playbook: aurora-connections-high.md"
  }

  aurora_freeable_memory_low = {
    namespace           = "AWS/RDS"
    metric_name         = "FreeableMemory"
    statistic           = "Average"
    comparison_operator = "LessThanThreshold"
    threshold           = 524288000
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 3
    treat_missing_data  = "notBreaching"
    severity            = "P2"
    dimensions = {
      DBClusterIdentifier = "CHANGE_ME"
    }
    description = "Aurora freeable memory below 500MB for 15 min. Playbook: aurora-memory-low.md"
  }

  aurora_free_storage_low = {
    namespace           = "AWS/RDS"
    metric_name         = "FreeLocalStorage"
    statistic           = "Average"
    comparison_operator = "LessThanThreshold"
    threshold           = 5368709120
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 3
    treat_missing_data  = "notBreaching"
    severity            = "P2"
    dimensions = {
      DBClusterIdentifier = "CHANGE_ME"
    }
    description = "Aurora free local storage below 5GB. Playbook: aurora-storage-low.md"
  }

  lambda_errors_high = {
    namespace           = "AWS/Lambda"
    metric_name         = "Errors"
    statistic           = "Sum"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 10
    period              = 300
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "notBreaching"
    severity            = "P2"
    dimensions = {
      FunctionName = "CHANGE_ME"
    }
    description = "Lambda errors exceeded 10 in 5 min. Playbook: lambda-errors.md"
  }

  lambda_throttles_high = {
    namespace           = "AWS/Lambda"
    metric_name         = "Throttles"
    statistic           = "Sum"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 10
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 2
    treat_missing_data  = "notBreaching"
    severity            = "P2"
    dimensions = {
      FunctionName = "CHANGE_ME"
    }
    description = "Lambda sustained throttles detected. Playbook: lambda-throttles.md"
  }

  s3_5xx = {
    namespace           = "AWS/S3"
    metric_name         = "5xxErrors"
    statistic           = "Sum"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 5
    period              = 300
    evaluation_periods  = 3
    datapoints_to_alarm = 2
    treat_missing_data  = "notBreaching"
    severity            = "P3"
    dimensions = {
      BucketName = "CHANGE_ME"
      FilterId   = "EntireBucket"
    }
    description = "S3 5xx errors detected. Prerequisite: S3 request metrics must be enabled. Playbook: s3-5xx.md"
  }

  cloudtrail_stop = {
    namespace           = "CloudTrailMetrics"
    metric_name         = "CloudTrailStopped"
    statistic           = "Sum"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    threshold           = 1
    period              = 300
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "breaching"
    severity            = "P1"
    dimensions          = {}
    description         = "CloudTrail logging stopped - security incident. Playbook: cloudtrail-stop-logging.md"
  }
}
