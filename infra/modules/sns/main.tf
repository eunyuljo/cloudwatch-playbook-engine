resource "aws_sns_topic" "p1p2" {
  name              = "msp-alerts-p1p2"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "SNS"
    Severity    = "P1-P2"
  }
}

resource "aws_sns_topic" "p3p4" {
  name              = "msp-alerts-p3p4"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "SNS"
    Severity    = "P3-P4"
  }
}

resource "aws_sns_topic_subscription" "p1p2_email" {
  topic_arn = aws_sns_topic.p1p2.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "p3p4_email" {
  topic_arn = aws_sns_topic.p3p4.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic" "runbook_results" {
  name              = "msp-runbook-results"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "Runbook"
  }
}

resource "aws_sns_topic_subscription" "runbook_results_email" {
  topic_arn = aws_sns_topic.runbook_results.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
