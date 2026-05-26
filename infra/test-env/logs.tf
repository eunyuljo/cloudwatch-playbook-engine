resource "aws_cloudwatch_log_group" "ecs_app" {
  name              = "/ecs/${var.project}-${var.environment}/app"
  retention_in_days = 1

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
