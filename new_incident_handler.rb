require 'date'
require 'json'
require 'securerandom'
require_relative 'aws_helpers'
require_relative 'slack_helpers'
require_relative 'app_mention_event_handlers/incident_helpers'

INCIDENT_BROADCAST_CHANNEL_ID = (ENV['INCIDENT_BROADCAST_CHANNEL_ID'] || '').freeze

def lambda_handler(event:, context:)
  slack_helper = SlackHelpers.new(Secrets.instance.slack_bot_oauth_token)
  incident_name = event.dig('incident_name')
  incident_priority = event.dig('incident_priority')
  incident_description = event.dig('incident_description')
  incident_commander = event.dig('incident_commander')
  user_id = event.dig('user_id')

  channel_created, channel_id = create_incident_channel(slack_helper, user_id, incident_name)
  if channel_created
    slack_helper.post_message(user_id, ":loudspeaker: New incident channel for '#{incident_name}' created. (<##{channel_id}>)")
    resp = slack_helper.invite_users(channel_id, [user_id, incident_commander])
    if resp.code.to_i != 200
      slack_helper.post_message(user_id, "Unable to invite users to incident channel <##{channel_id}>. Response code: #{resp.code}, Response body: ```#{resp.body}```")
    end
    incident_message_title = ":warning: New Incident: #{incident_name} :warning:"
    incident_message_body = new_incident_body_text(incident_commander, user_id, channel_id, incident_description, incident_priority)
    resp = slack_helper.post_channel_message(channel_id, incident_message_body, title: incident_message_title, color: "#FF0000")
    if resp.code.to_i != 200
      slack_helper.post_message(user_id, "Unable to broadcast new incident status to <##{channel_id}>")
    end
    set_incident_topic(slack_helper, channel_id, incident_commander, incident_name)
    if INCIDENT_BROADCAST_CHANNEL_ID != ''
      slack_helper.post_channel_message(INCIDENT_BROADCAST_CHANNEL_ID, incident_message_body, title: incident_message_title, color: "#FF0000")
    end
  else
    slack_helper.post_message(user_id, "Unable to create incident channel. Response code: #{resp.code}, Response body: ```#{resp.body}```")
  end
end

def create_incident_channel(slack_helper, user_id, incident_name)
  formatted_name = format_incident_name(incident_name)
  resp = slack_helper.create_channel(formatted_name)
  if resp.code.to_i == 200
    parsed_resp = JSON.parse(resp.body)
    channel_created = parsed_resp.dig('ok')
    if channel_created
      channel_id = parsed_resp.dig('channel', 'id')
      [channel_created, channel_id]
    else
      error = parsed_resp.dig('error')
      if error == 'name_taken'
        return create_incident_channel(slack_helper, "#{incident_name}-#{SecureRandom.hex(2)}")
      else
        slack_helper.post_message(user_id, "Unable to create incident channel. Error: `#{error}`")
      end
    end
  else
    slack_helper.post_message(user_id, "Unable to create incident channel. Response code: #{resp.code}, Response body: ```#{resp.body}```")
    return [false, nil]
  end
end

def set_incident_topic(slack_helper, channel_id, commander, incident_name)
  topic = IncidentHelpers.serialize_topic({
    status: 'Ongoing',
    commander: "<@#{commander}>",
    incident_name: incident_name[0...150]
  })
  slack_helper.set_channel_topic(channel_id, topic)
end

def format_incident_name(incident_name)
  # Lowercase the incident name
  formatted_name = incident_name.downcase
  # Replace spaces with dashes
  formatted_name = formatted_name.gsub(' ', '-')
  # strip out non-alphanumeric chars and extra dashes
  formatted_name = formatted_name.gsub(/[^0-9a-zA-Z\-]/, '').gsub(/-+/, '-').strip
  # Truncate the string at 65 chars
  formatted_name = formatted_name[0, 65]
  # Prefix the string with "inc-YYYYMMDD-"
  current_date_time = DateTime.now
  current_date_time_string = current_date_time.strftime("%Y%m%d")
  formatted_name = "inc-#{current_date_time_string}-#{formatted_name}"
  formatted_name
end

def new_incident_body_text(incident_commander, user_id, incident_channel_id, incident_description, incident_priority)
  text = <<~EOM
*:fire_engine: Incident Commander*: <@#{incident_commander}>
*:speech_balloon: Reported By*: <@#{user_id}>
*:vertical_traffic_light: Priority*: #{incident_priority} #{priority_emoji(incident_priority)}
*:loudspeaker: Incident Channel*: <##{incident_channel_id}>
  EOM
  text << "*:memo: Description*: #{incident_description}" unless incident_description.nil? || incident_description.strip == ''
  text
end

def priority_emoji(incident_priority)
  case incident_priority.downcase
  when 'p1'
    ':large_red_square:'
  when 'p2'
    ':red_circle:'
  when 'p3'
    ':large_yellow_circle:'
  when 'p4'
    ':large_blue_circle:'
  when 'p5'
    ':white_circle:'
  else
    ':question:'
  end
end
