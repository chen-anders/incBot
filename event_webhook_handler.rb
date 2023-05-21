require 'json'
require_relative 'slack_helpers'

class EventWebhookHandler
  ORANGE_COLOR = '#FFA500'.freeze
  GREEN_COLOR = '#008000'.freeze
  BLUE_COLOR = '#0818A8'.freeze
  VALID_CHANNEL_NAME = /^inc-\d{8}-[a-z0-9-]+$/

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
        remaining_text = message_text.sub(command, '').strip
        ts = body.dig('event', 'thread_ts') || body.dig('event', 'ts')

        case command
        when 'incident-update', 'update-incident', 'resolve-incident'
          return post_not_in_incident_channel_message(channel_id, ts) unless incident_channel?(channel_id)
          color = (command == 'resolve-incident' ? GREEN_COLOR : ORANGE_COLOR)
          icon = (command == 'resolve-incident' ? ':white_check_mark:' : ':zap:')
          remaining_text = (command == 'resolve-incident' && remaining_text == '' ? 'Incident is now resolved.' : remaining_text)
          if @incident_broadcast_channel_id != ''
            post_channel_message(
              @incident_broadcast_channel_id,
              title: "#{icon} Incident update (<##{channel_id}>) #{icon}",
              message: "<@#{originating_user}>: #{remaining_text}",
              color: color
            )
            post_channel_message(
              channel_id,
              title: "#{icon} Update posted to <##{@incident_broadcast_channel_id}>",
              message: "<@#{originating_user}>: #{remaining_text}",
              color: color
            )
          else
            slack_helper.reply_in_thread(channel_id, ts, ":x: No incident broadcast channel configured to post incident update.")
          end
        when 'incident-handoff', 'handoff'
          return post_not_in_incident_channel_message(channel_id, ts) unless incident_channel?(channel_id)
          if remaining_text.downcase == 'me' || /^<@U[A-Z0-9]+>$/.match?(remaining_text)
            commander = (remaining_text == 'me' ? " <@#{originating_user}>" : remaining_text)
            slack_helper.set_channel_topic(channel_id, "Incident Commander: #{commander}")
            if @incident_broadcast_channel_id != ''
              post_channel_message(
                @incident_broadcast_channel_id,
                title: ":rotating_light: Incident Update :rotating_light:",
                message:"<##{channel_id}>: #{commander} is now Incident Commander.",
                color: BLUE_COLOR
              )
            end
            post_channel_message(
              channel_id,
              title: ":rotating_light: Incident Update :rotating_light:",
              message: "#{commander} is now Incident Commander.",
              color: BLUE_COLOR
            )
          else
            slack_helper.reply_in_thread(channel_id, ts, ":x: New incident commander must be a valid Slack user.")
          end
        else
          slack_helper.reply_in_thread(channel_id, ts, ":x: `#{command}` is not a valid command. Valid commands: `update-incident`, `resolve-incident`, `incident-handoff`")
        end
      end
    end
    { statusCode: 200 }
  end

  private

  def incident_channel?(channel_id)
    resp = slack_helper.channel_info(channel_id)
    if resp.code.to_i == 200
      parsed_resp = JSON.parse(resp.body)
      channel_name = parsed_resp.dig('channel', 'name')
      VALID_CHANNEL_NAME.match?(channel_name)
    else
      raise "Unable to determine whether channel ID: #{channel_id} is a valid incident channel"
    end
  end

  def post_not_in_incident_channel_message(channel_id, ts)
    slack_helper.reply_in_thread(channel_id, ts, ":bangbang: This command can only be used in a valid incident channel.")
  end

  def post_channel_message(channel_id, title:, message:, color: ORANGE_COLOR)
    slack_helper.post_channel_message(channel_id, message, title: title, color: color)
  end

  def body
    @body
  end

  def slack_helper
    @slack_helper
  end
end
