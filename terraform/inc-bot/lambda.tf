locals {
  url_handlers   = ["main"]
  async_handlers = ["main", "new_incident"]
}

resource "aws_lambda_function" "handlers" {
  for_each      = toset(concat(local.url_handlers, local.async_handlers))
  architectures = ["arm64"]

  ephemeral_storage {
    size = "512"
  }

  function_name                  = "${var.name}_handler_${each.key}"
  handler                        = "${each.key}_handler.lambda_handler"
  memory_size                    = "256"
  package_type                   = "Zip"
  reserved_concurrent_executions = "-1"
  role                           = aws_iam_role.incident-helper-iam-role.arn
  runtime                        = "ruby3.2"
  filename                       = "../lambda-function.zip"
  publish                        = false

  environment {
    variables = {
      SECRET_NAME                   = var.secrets_key
      INCIDENT_BROADCAST_CHANNEL_ID = var.incident_broadcast_channel_id
      NEW_INCIDENT_HANDLER_NAME     = "${var.name}_handler_new_incident"
      PAGERDUTY_EMAIL               = var.pagerduty_email
    }
  }

  tags = {
    cost-center = "incident-helper"
  }

  tags_all = {
    cost-center = "incident-helper"
  }

  timeout = "29"

  tracing_config {
    mode = "PassThrough"
  }

  lifecycle {
    ignore_changes = [filename, publish]
  }
}

resource "aws_lambda_function_url" "url_handlers" {
  for_each           = toset(local.url_handlers)
  function_name      = aws_lambda_function.handlers[each.key].function_name
  authorization_type = "NONE"
}
