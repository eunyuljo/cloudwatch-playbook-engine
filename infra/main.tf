terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
