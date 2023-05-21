require 'json'
require_relative 'aws_helpers'
require_relative 'slack_helpers'
require_relative 'slack_modals'

class InteractionPayloadHandler
  def initialize(body)
    @event_body = body
    @slack_helper = SlackHelpers.new(Secrets.instance.slack_bot_oauth_token)
    @new_incident_handler_name = ENV['NEW_INCIDENT_HANDLER_NAME']
  end

  def is_shortcut?
    body = parse_interaction_payloads(@event_body)
    action_type = body.dig('type')
    action_type == 'shortcut'
  end

  def handle
    body = parse_interaction_payloads(@event_body)
    action_type = body.dig('type')
    case action_type
    when 'url_verification'
      return { statusCode: 200, body: body['challenge'] }
    when 'shortcut'
      callback_id = body.dig('callback_id')
      user_id = body.dig('user', 'id')
      case callback_id
      when 'new_incident'
        # Construct the modal payload
        modal_payload = NewIncidentModal.modal_json(body.dig('trigger_id'), user_id)
        slack_helper.present_modal(modal_payload)
      end
    when 'view_submission'
      callback_id = body.dig('view', 'callback_id')
      case callback_id
      when 'incident_submission'
        incident_name = body.dig('view', 'state', 'values', 'incident_name', 'incident_name_input', 'value')
        incident_priority = body.dig('view', 'state', 'values', 'incident_priority', 'incident_priority_input', 'selected_option', 'text', 'text') || 'unknown'
        incident_description = body.dig('view', 'state', 'values', 'incident_description', 'incident_description_input', 'value') || ''
        incident_commander = body.dig('view', 'state', 'values', 'incident_commander', 'incident_commander_input', 'selected_user')
        user_id = body.dig('user', 'id')
        payload = {
          incident_name: incident_name,
          incident_description: incident_description,
          incident_commander: incident_commander,
          incident_priority: incident_priority,
          user_id: user_id,
        }
        if @new_incident_handler_name
          Lambda.invoke_function(@new_incident_handler_name, payload)
        else
          slack_helper.post_message(user_id, ":x: New incident handler not properly configured.")
        end
      end
    end
    { statusCode: 200, body: ''}
  end

  private

  def slack_helper
    @slack_helper
  end

  def parse_interaction_payloads(payload)
    obj = URI.decode_www_form(payload).to_h
    JSON.parse(obj['payload'])
  end
end
