output "lambda_function_arn" {
  description = "Runbook engine Lambda function ARN"
  value       = aws_lambda_function.runbook_engine.arn
}

output "lambda_function_name" {
  description = "Runbook engine Lambda function name"
  value       = aws_lambda_function.runbook_engine.function_name
}

output "lambda_role_arn" {
  description = "Runbook engine Lambda IAM role ARN"
  value       = aws_iam_role.runbook_lambda.arn
}
