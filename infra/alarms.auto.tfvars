alarms = {
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
      LoadBalancer = "app/msp-monitoring-test-alb/69405672531aaae2"
    }
    description = "ALB-level 5xx count exceeded 10 in 5 min. Playbook: alb-elb-5xx.md"
  }

  alb_target_5xx = {
    namespace           = "AWS/ApplicationELB"
    metric_name         = "HTTPCode_Target_5XX_Count"
    statistic           = "Sum"
    comparison_operator = "GreaterThanThreshold"
    threshold           = 5
    period              = 60
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "notBreaching"
    severity            = "P2"
    dimensions = {
      LoadBalancer = "app/msp-monitoring-test-alb/69405672531aaae2"
      TargetGroup  = "targetgroup/msp-monitoring-test-tg/f482d387343c43c1"
    }
    description = "ALB target 5xx count exceeded 5 in 1 min. Playbook: alb-target-5xx.md"
  }

  alb_unhealthy_host = {
    namespace           = "AWS/ApplicationELB"
    metric_name         = "UnHealthyHostCount"
    statistic           = "Maximum"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    threshold           = 1
    period              = 60
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "breaching"
    severity            = "P1"
    dimensions = {
      LoadBalancer = "app/msp-monitoring-test-alb/69405672531aaae2"
      TargetGroup  = "targetgroup/msp-monitoring-test-tg/f482d387343c43c1"
    }
    description = "ALB unhealthy host detected. Playbook: alb-unhealthy-host.md"
  }

  ecs_running_task_low = {
    namespace           = "ECS/ContainerInsights"
    metric_name         = "RunningTaskCount"
    statistic           = "Minimum"
    comparison_operator = "LessThanThreshold"
    threshold           = 1
    period              = 60
    evaluation_periods  = 1
    datapoints_to_alarm = 1
    treat_missing_data  = "breaching"
    severity            = "P1"
    dimensions = {
      ClusterName = "msp-monitoring-test-cluster"
      ServiceName = "msp-monitoring-test-app"
    }
    description = "ECS running task count below desired. Playbook: ecs-task-count-low.md"
  }

  ecs_cpu_high = {
    namespace           = "ECS/ContainerInsights"
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
      ClusterName = "msp-monitoring-test-cluster"
      ServiceName = "msp-monitoring-test-app"
    }
    description = "ECS CPU utilization exceeded 80% for 15 min. Playbook: ecs-cpu-high.md"
  }

  ecs_memory_high = {
    namespace           = "ECS/ContainerInsights"
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
      ClusterName = "msp-monitoring-test-cluster"
      ServiceName = "msp-monitoring-test-app"
    }
    description = "ECS memory utilization exceeded 85% for 10 min. Playbook: ecs-memory-high.md"
  }
}
