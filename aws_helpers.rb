require 'aws-sdk-lambda'
require 'aws-sdk-secretsmanager'
require 'base64'
require 'json'
require 'singleton'

SECRET_NAME = (ENV["SECRET_NAME"] || "app/incident-helper/secrets").freeze
AWS_REGION = (ENV['AWS_REGION'] || 'us-east-1').freeze

class Secrets
  include Singleton
  attr_reader :slack_signing_secret, :slack_bot_oauth_token, :pagerduty_api_key

  def initialize
    fetch_secrets
  end

  private

  def fetch_secrets
    # Initialize the Secrets Manager client
    secrets_manager = Aws::SecretsManager::Client.new(region: AWS_REGION)

    # Retrieve the secret value
    response = secrets_manager.get_secret_value(secret_id: SECRET_NAME)

    # Parse the secret value JSON
    secret_data = JSON.parse(response.secret_string)

    # Access the required keys
    @slack_signing_secret = secret_data['SLACK_SIGNING_SECRET']
    @slack_bot_oauth_token = secret_data['SLACK_BOT_OAUTH_TOKEN']
    @pagerduty_api_key = secret_data['PAGERDUTY_API_KEY']
  end
end


class Lambda
  def self.invoke_function(lambda_name, payload)
    lambda_client = Aws::Lambda::Client.new(region: AWS_REGION)
    lambda_client.invoke(function_name: lambda_name, payload: payload.to_json, invocation_type: "Event")
  end

  def self.handle_lambda_event_body(event)
    body_is_b64_encoded = event.dig('isBase64Encoded') || false
    event_body = event.dig('body')
    event_body = Base64.decode64(event_body) if body_is_b64_encoded
    event_body
  end
end
