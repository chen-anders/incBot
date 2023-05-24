class IncidentHelpers
  class IncidentHelpersError < StandardError; end
  VALID_CHANNEL_NAME = /^inc-\d{8}-[a-z0-9-]+$/
  TOPIC_REGEX = /^Status:\s*(?<status>\w+)\s*\|\s*Incident Commander:\s*(?<commander><@U[0-9A-Z]+>)\s*\|\s*Name:\s*(?<name>.+)\s*/
  def self.incident_channel?(incident_info)
    incident_info[:is_incident_channel]
  end

  def self.post_not_in_incident_channel_message(slack_helper, channel_id, ts)
    slack_helper.reply_in_thread(channel_id, ts, ":bangbang: This command can only be used in a valid incident channel.")
  end

  def self.incident_broadcast_channel_id
    ENV['INCIDENT_BROADCAST_CHANNEL_ID']
  end

  def self.serialize_topic(attrs)
    "Status: #{attrs[:status]} | Incident Commander: #{attrs[:commander]} | Name: #{attrs[:incident_name]}".strip
  end

  def self.deserialize_topic(topic)
    m = TOPIC_REGEX.match(topic.strip)
    if m
      {
        status: m['status'].strip,
        commander: m['commander'].strip,
        incident_name: m['name'].strip
      }
    end
  end

  def self.incident_info(slack_helper, channel_id)
    resp = slack_helper.channel_info(channel_id)
    if resp.code.to_i == 200
      parsed_resp = JSON.parse(resp.body)
      if parsed_resp.dig('ok') == true
        channel_info = parsed_resp.dig('channel')
        channel_name = channel_info.dig('name')
        is_incident_channel = VALID_CHANNEL_NAME.match?(channel_name)
        data = { is_incident_channel: is_incident_channel }
        if is_incident_channel
          topic = channel_info.dig('topic', 'value')
          p deserialize_topic(topic)
          if topic
            data = data.merge(deserialize_topic(topic))
          end
        end
        data
      else
        raise IncidentHelpersError.new("error: #{parsed_resp.dig('error')}")
      end
    else
      raise IncidentHelpersError.new("Unable to determine whether channel ID: #{channel_id} is a valid incident channel")
    end
  end
end
