provider "aws" {
  region = "ap-southeast-2" # Melbourne
}

# SNS Topic and Email Subscription
resource "aws_sns_topic" "rds_patch_notifications" {
  name = "rds-patch-notifications"
}

resource "aws_sns_topic_subscription" "team_email" {
  topic_arn = aws_sns_topic.rds_patch_notifications.arn
  protocol  = "email"
  endpoint  = "your-email@example.com" # Replace with your team email
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_rds_patch" {
  name = "lambda-rds-patch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_rds_patch_policy" {
  name = "lambda-rds-patch-policy"
  role = aws_iam_role.lambda_rds_patch.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribePendingMaintenanceActions",
          "rds:ApplyPendingMaintenanceAction"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "sns:Publish"
        ],
        Effect = "Allow",
        Resource = aws_sns_topic.rds_patch_notifications.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "rds_patch_scheduler" {
  function_name = "rds-patch-scheduler"
  role          = aws_iam_role.lambda_rds_patch.arn
  runtime       = "python3.10"
  handler       = "lambda_function.lambda_handler"
  timeout       = 30

  filename         = "lambda/lambda.zip"
  source_code_hash = filebase64sha256("lambda/lambda.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.rds_patch_notifications.arn
    }
  }
}

# EventBridge Rule (Weekly Trigger)
resource "aws_cloudwatch_event_rule" "rds_patch_schedule" {
  name                = "rds-patch-schedule"
  schedule_expression = "cron(55 14 ? * FRI *)" # 12:55 AM Saturday AEST
}

resource "aws_cloudwatch_event_target" "rds_patch_target" {
  rule      = aws_cloudwatch_event_rule.rds_patch_schedule.name
  target_id = "rds-patch-lambda"
  arn       = aws_lambda_function.rds_patch_scheduler.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_patch_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_patch_schedule.arn
}
