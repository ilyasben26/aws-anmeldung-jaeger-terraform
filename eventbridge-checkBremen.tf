# Create an EventBridge rule (scheduler) that triggers every 5 minutes
resource "aws_cloudwatch_event_rule" "lambda_scheduler_rule" {
  name                = "aj-checkBremen-lambda-scheduler"
  schedule_expression = "rate(5 minutes)" # Trigger every 5 minutes
  state               = "DISABLED"
}

# Create a target for the EventBridge rule to invoke the Lambda function
resource "aws_cloudwatch_event_target" "invoke_lambda_target" {
  rule = aws_cloudwatch_event_rule.lambda_scheduler_rule.name
  arn  = aws_lambda_function.terraform_lambda_func.arn
}

# Permission for EventBridge to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_lambda_func.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_scheduler_rule.arn
}
