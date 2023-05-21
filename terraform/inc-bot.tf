module "inc-bot" {
  source = "./inc-bot"

  name        = "inc-bot"
  secrets_key = "app/inc-bot/secrets"

  incident_broadcast_channel_id = "C23SFSW1L"
  pagerduty_email               = "my-test-email@testing.com"
}
