resource "aws_cloudwatch_event_target" "lambda-warmer" {
  count = (var.enable_lambda_warmer == true ? 1 : 0)
  arn   = aws_lambda_function.handlers["main"].arn
  rule  = aws_cloudwatch_event_rule.lambda-warmer[0].id
  input = jsonencode({
    rawPath = "/_lambda_warmer"
  })
}

resource "aws_cloudwatch_event_rule" "lambda-warmer" {
  count       = (var.enable_lambda_warmer == true ? 1 : 0)
  name        = "${var.name}-main-endpoint-lambda-warmer-${count.index}"
  description = "Lambda warmer for main endpoint"

  schedule_expression = "rate(7 minutes)"
}

resource "aws_lambda_permission" "allow-lambda-warmer" {
  count         = (var.enable_lambda_warmer == true ? 1 : 0)
  statement_id  = "AllowExecutionFromLambdaWarmer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handlers["main"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda-warmer[0].arn
}
