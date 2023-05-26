module "inc-bot" {
  source = "./inc-bot"

  name        = "inc-bot"
  secrets_key = "app/inc-bot/secrets"

  incident_broadcast_channel_id = "C23SFSW1L"
  pagerduty_email               = "engineering-accounts@wistia.com"
  enable_lambda_warmer          = true
}

module "inc-bot-testing" {
  source = "./inc-bot"

  name        = "inc-bot-testing"
  secrets_key = "app/incident-helper-testing-bot/secrets"

  incident_broadcast_channel_id = "C058J95SNVC"
  pagerduty_email               = "engineering-accounts@wistia.com"
  enable_lambda_warmer          = false
}
