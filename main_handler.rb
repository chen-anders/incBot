require 'json'
require 'openssl'
require 'base64'
require_relative 'aws_helpers'
require_relative 'slack_helpers'
require_relative 'event_webhook_handler'
require_relative 'interaction_payload_handler'

INTERACTION_PAYLOAD_ROUTE = '/interaction_payload'.freeze
EVENTS_ROUTE = '/events'.freeze
HEALTHZ_ROUTE = '/healthz'.freeze
LAMBDA_WARMER_ROUTE  = '/_lambda_warmer'.freeze

def lambda_handler(event:, context:)
  path = event.dig('rawPath')
  return { statusCode: 200, body: 'OK' } if path == HEALTHZ_ROUTE
  if path == LAMBDA_WARMER_ROUTE
    STDERR.puts "Request to #{LAMBDA_WARMER_ROUTE} received"
    Lambda.invoke_function(ENV.fetch('AWS_LAMBDA_FUNCTION_NAME'), { rawPath: HEALTHZ_ROUTE })
    return { statusCode: 200, body: 'OK' }
  end
  return { statusCode: 404, body: 'Not Found' } unless [INTERACTION_PAYLOAD_ROUTE, EVENTS_ROUTE].include?(path)

  already_authenticated = event.dig('lambda_auth') || false
  if !already_authenticated
    slack_signature = event.dig('headers', 'x-slack-signature')
    slack_timestamp = event.dig('headers', 'x-slack-request-timestamp')
    return { statusCode: 400, body: "Missing headers" } unless slack_signature && slack_timestamp

    slack_signing_secret = Secrets.instance.slack_signing_secret
    event_body = Lambda.handle_lambda_event_body(event)
    if SlackHelpers.verify_signature(slack_signature, slack_timestamp, slack_signing_secret, event_body)
      if path == INTERACTION_PAYLOAD_ROUTE && (h = InteractionPayloadHandler.new(event_body)) && h.is_shortcut?
        return h.handle
      elsif path == EVENTS_ROUTE && (h = EventWebhookHandler.new(event_body)) && h.is_verification?
        return { statusCode: 200, body: h.verification_payload}
      else
        STDERR.puts "Launching async lambda (#{ENV.fetch('AWS_LAMBDA_FUNCTION_NAME')})"
        Lambda.invoke_function(ENV.fetch('AWS_LAMBDA_FUNCTION_NAME'), {
          lambda_auth: true,
          rawPath: path,
          body: event.dig('body'),
          isBase64Encoded: event.dig('isBase64Encoded') || false
        })
        { statusCode: 200 }
      end
    else
      return {
        statusCode: 403,
        body: 'Invalid Slack signature'
      }
    end
  else
    event_body = Lambda.handle_lambda_event_body(event)
    case path
    when EVENTS_ROUTE
      EventWebhookHandler.new(event_body).handle
    when INTERACTION_PAYLOAD_ROUTE
      InteractionPayloadHandler.new(event_body).handle
    end
  end
end
