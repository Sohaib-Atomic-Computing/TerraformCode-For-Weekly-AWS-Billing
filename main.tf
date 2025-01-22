provider "aws" {
  region     = "eu-central-1"
  access_key = var.access_key #Add your aws access key here
  secret_key = var.secret_key #Add your aws secret key here
  token      = var.token      #Add your aws token here if you're using temporary credentials like SSO or AssumeRole if not then remove this line
}

# Create IAM Role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role_for_aws_weekly_billing"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach CloudWatch Logs Full Access Policy
resource "aws_iam_policy_attachment" "cloudwatch_logs" {
  name       = "cloudwatch-logs-policy-attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Attach Billing Read Only Access Policy
resource "aws_iam_policy_attachment" "billing_read_only" {
  name       = "billing-read-only-policy-attachment"
  roles      = [aws_iam_role.lambda_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

# Create Lambda Function
resource "aws_lambda_function" "example_lambda" {
  function_name = "AWS_Weekly_Billing_Lambda_Function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 300 # Set the timeout to 5 minutes (300 seconds)

  # Path to the Lambda function's deployment package
  filename = "lambda_function.zip"

  # Define environment variables for the Lambda function
  environment {
    variables = {
      ACCOUNT_NAME      = var.account_name,
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

# Allow Lambda to be invoked by EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.function_name
  principal     = "events.amazonaws.com"
}

# Create EventBridge Rule to trigger Lambda function every Monday at 10:00 AM Karachi time
resource "aws_cloudwatch_event_rule" "weekly_schedule" {
  name                = "Weekly-Billing-Lambda-Fuction-Trigger"
  description         = "Weekly EventBridge Rule to trigger Lambda function every Monday at 10:00 AM Karachi time"
  schedule_expression = "cron(0 5 ? * MON *)" # 5 AM UTC is 10 AM Karachi time
}

# Create EventBridge Target to invoke Lambda function
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.weekly_schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.example_lambda.arn
}

# Allow EventBridge to invoke Lambda function
resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_schedule.arn
}
