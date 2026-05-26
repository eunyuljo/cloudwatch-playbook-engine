data "archive_file" "runbook_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/runbook_engine"
  output_path = "${path.module}/files/runbook_engine.zip"
}

resource "aws_sqs_queue" "runbook_dlq" {
  name                      = "${var.project}-${var.environment}-runbook-dlq"
  message_retention_seconds = 1209600

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "Runbook"
  }
}

resource "aws_lambda_function" "runbook_engine" {
  function_name                  = "${var.project}-${var.environment}-runbook-engine"
  handler                        = "handler.lambda_handler"
  runtime                        = "python3.12"
  timeout                        = 60
  memory_size                    = 256
  reserved_concurrent_executions = 5
  role                           = aws_iam_role.runbook_lambda.arn
  filename                       = data.archive_file.runbook_lambda.output_path
  source_code_hash               = data.archive_file.runbook_lambda.output_base64sha256

  dead_letter_config {
    target_arn = aws_sqs_queue.runbook_dlq.arn
  }

  environment {
    variables = {
      PROJECT                = var.project
      ENVIRONMENT            = var.environment
      NOTIFICATION_TOPIC_ARN = var.notification_topic_arn
      ECS_CLUSTER_NAME       = var.ecs_cluster_name
      ECS_SERVICE_NAME       = var.ecs_service_name
      APP_LOG_GROUP_NAME     = var.app_log_group_name
      TARGET_GROUP_ARN       = var.target_group_arn
      LOG_LEVEL              = var.log_level
    }
  }

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "Runbook"
  }
}

resource "aws_cloudwatch_log_group" "runbook_lambda" {
  name              = "/aws/lambda/${var.project}-${var.environment}-runbook-engine"
  retention_in_days = 30

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "runbook_trigger" {
  topic_arn = var.sns_topic_arn_p1p2
  protocol  = "lambda"
  endpoint  = aws_lambda_function.runbook_engine.arn
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.runbook_engine.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.sns_topic_arn_p1p2
}

resource "aws_iam_role" "runbook_lambda" {
  name = "${var.project}-${var.environment}-runbook-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "runbook_diagnostics" {
  name = "${var.project}-${var.environment}-runbook-diagnostics"
  role = aws_iam_role.runbook_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ELBReadOnly"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeLoadBalancers"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSReadOnly"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:ListTasks"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:FilterLogEvents",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.notification_topic_arn]
      },
      {
        Sid      = "DLQSend"
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [aws_sqs_queue.runbook_dlq.arn]
      },
      {
        Sid    = "LambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.runbook_lambda.arn}:*"
      }
    ]
  })
}
