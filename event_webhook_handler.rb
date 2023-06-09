require 'json'
require_relative 'slack_helpers'
require_relative 'app_mention_event_handlers/base'
require_relative 'app_mention_event_handlers/incident_helpers'
Dir["app_mention_event_handlers/*handler.rb"].each { |handler| require_relative(handler) }

class EventWebhookHandler
  def initialize(event_body)
    @body = JSON.parse(event_body)
    @slack_helper = SlackHelpers.new(Secrets.instance.slack_bot_oauth_token)
    @incident_broadcast_channel_id = (ENV['INCIDENT_BROADCAST_CHANNEL_ID'] || '')
  end

  def is_verification?
    body.dig('type') == 'url_verification'
  end

  def verification_payload
    { statusCode: 200, body: body.dig('challenge') }
  end

  def valid_cmd_txt
    "Valid commands: `new-incident`, `update-incident`, `resolve-incident`, `incident-handoff`, `oncall`, `oncall-teams`, `page`"
  end

  def usage_txt
    <<~EOM
    ---
    Usage: `@incBot [optional args] <required args>`

    *Check who is oncall for a service*: `@incBot oncall <service-name>`
    *Look up defined oncall teams*: `@incBot oncall-teams`
    *Page the current oncall for a service*: `@incBot page <service-name> <message>`

    *Create Incident*: `@incBot new-incident [P1/P2/P3/P4/P5/leave blank if unknown] <incident-name>`
    *Broadcast Incident Update*: `@incBot update-incident <message>`
    *Broadcast Incident Resolution Note*: `@incBot resolve-incident <message>`
    *Handoff Incident Commander Role*: `@incBot handoff <SLACK_USER or me>`
    EOM
  end

  def handle
    return verification_payload if is_verification?
    event_type = body.dig('event', 'type')
    case event_type
    when 'app_mention'
      user_id = slack_helper.whoami
      originating_user = body.dig('event', 'user')
      message_text = body.dig('event', 'text')
      channel_id = body.dig('event', 'channel')

      if message_text.start_with?("<@#{user_id}>")
        message_text = message_text.sub("<@#{user_id}>", '')
        command = message_text.split(' ').first
        command_args = (command ? message_text.sub(command, '').strip : '')
        ts = body.dig('event', 'thread_ts') || body.dig('event', 'ts')

        case command
        when nil, 'help'
          slack_helper.reply_in_thread(channel_id, ts, "#{valid_cmd_txt}\n#{usage_txt}")
        when 'create-incident', 'new-incident'
          AppMentionEventHandlers::CreateIncidentHandler.new(body, user_id, command_args).handle
        when 'incident-update', 'update-incident'
          AppMentionEventHandlers::UpdateIncidentHandler.new(body, user_id, command_args).handle
        when 'resolve-incident'
          AppMentionEventHandlers::ResolveIncidentHandler.new(body, user_id, command_args).handle
        when 'incident-handoff', 'handoff'
          AppMentionEventHandlers::HandoffIncidentHandler.new(body, user_id, command_args).handle
        when 'oncall-team', 'oncall-teams'
          AppMentionEventHandlers::OncallTeamsHandler.new(body, user_id, command_args).handle
        when 'oncall'
          AppMentionEventHandlers::OncallHandler.new(body, user_id, command_args).handle
        when 'page'
          AppMentionEventHandlers::PageHandler.new(body, user_id, command_args).handle
        else
          slack_helper.reply_in_thread(channel_id, ts, ":x: `#{command}` is not a valid command. #{valid_cmd_txt}\n#{usage_txt}")
        end
      end
    end
    { statusCode: 200 }
  end

  private

  def body
    @body
  end

  def slack_helper
    @slack_helper
  end
end
