resource "aws_iam_role" "incident-helper-iam-role" {
  name               = "${var.name}-incident-helper-iam-role"
  description        = "IAM role for ${var.name} Incident Helper Slack Bot"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "${var.name}-incident-helper-iam-role"
  }
}

locals {
  log_group_arn_prefix = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda"
  lambda_arn_prefix    = "arn:aws:lambda:${local.region}:${local.account_id}:function"
}

locals {
  log_groups         = [for handler in toset(concat(local.url_handlers, local.async_handlers)) : "${local.log_group_arn_prefix}/${var.name}_handler_${handler}:*"]
  async_handler_arns = [for handler in local.async_handlers : "${local.lambda_arn_prefix}:${var.name}_handler_${handler}"]
}

resource "aws_iam_policy" "policy" {
  name        = "${var.name}-incident-helper-iam-policy"
  path        = "/"
  description = "Lambda Role for ${var.name} Incident Helper Slack Bot"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.secrets_key}*"]
      },
      {
        Action = [
          "lambda:InvokeFunction",
        ]
        Effect   = "Allow"
        Resource = local.async_handler_arns
      },
      {
        Action = [
          "logs:CreateLogGroup"
        ],
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = local.log_groups
      }
    ]
  })

  tags = {
    Name = "${var.name}-incident-helper-iam-policy"
  }
}

resource "aws_lambda_permission" "allow_function_url_execution" {
  for_each      = toset(local.url_handlers)
  statement_id  = "AllowLambdaFunctionUrlExecution"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.handlers[each.key].function_name
  principal     = "*"

  function_url_auth_type = "NONE"
}


resource "aws_iam_role_policy_attachment" "lambda-attach" {
  role       = aws_iam_role.incident-helper-iam-role.name
  policy_arn = aws_iam_policy.policy.arn
}
