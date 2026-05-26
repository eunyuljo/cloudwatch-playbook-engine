output "alb_dns_name" {
  value = module.alb.dns_name
}

output "alb_arn_suffix" {
  value = module.alb.arn_suffix
}

output "target_group_arn" {
  value = module.alb.target_groups["ecs"].arn
}

output "target_group_arn_suffix" {
  value = replace(module.alb.target_groups["ecs"].arn, "/.*:targetgroup/", "targetgroup")
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ecs_app.name
}
