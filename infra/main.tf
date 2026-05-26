terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "local" {}
}

provider "aws" {
  region = var.region
}

module "sns" {
  source = "./modules/sns"

  project     = var.project
  environment = var.environment
  alert_email = var.alert_email
}

module "alarms" {
  source = "./modules/alarms"

  project     = var.project
  environment = var.environment
  alarms      = var.alarms

  sns_topic_arn_p1p2 = module.sns.topic_arn_p1p2
  sns_topic_arn_p3p4 = module.sns.topic_arn_p3p4
}

module "runbook" {
  source = "./modules/runbook"

  project                = var.project
  environment            = var.environment
  sns_topic_arn_p1p2     = module.sns.topic_arn_p1p2
  notification_topic_arn = module.sns.topic_arn_runbook_results
  ecs_cluster_name       = var.ecs_cluster_name
  ecs_service_name       = var.ecs_service_name
  app_log_group_name     = var.app_log_group_name
  target_group_arn       = var.target_group_arn
  log_level              = var.runbook_log_level
}
