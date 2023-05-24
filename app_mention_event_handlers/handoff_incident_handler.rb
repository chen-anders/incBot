class AppMentionEventHandlers::HandoffIncidentHandler < AppMentionEventHandlers::Base
  ICON = ':rotating_light:'.freeze

  def handle
    return IncidentHelpers.post_not_in_incident_channel_message(slack_helper, channel_id, ts) unless IncidentHelpers.incident_channel?(incident_info)
    if command_args.downcase == 'me' || /^<@U[A-Z0-9]+>$/.match?(command_args)
      commander = (command_args == 'me' ? " <@#{originating_user}>" : command_args)
      update_channel_topic(commander)
      if IncidentHelpers.incident_broadcast_channel_id
        post_channel_message(
          IncidentHelpers.incident_broadcast_channel_id,
          title: "#{ICON} Incident Update: #{incident_info[:incident_name]} #{ICON}",
          message: "*Channel*: <##{channel_id}>\n*Status*: #{incident_info[:status]}\n#{commander} is now Incident Commander.",
          color: BLUE_COLOR
        )
      end
      post_channel_message(
        channel_id,
        title: "#{ICON} Incident Update #{ICON}",
        message: "#{commander} is now Incident Commander.",
        color: BLUE_COLOR
      )
    else
      slack_helper.reply_in_thread(channel_id, ts, ":x: New incident commander must be a valid Slack user.")
    end
  end

  def update_channel_topic(commander)
    topic = IncidentHelpers.serialize_topic(incident_info.merge({ commander: commander }))
    slack_helper.set_channel_topic(channel_id, topic)
    @incident_info = incident_info.merge({ commander: commander })
  end

  def incident_info
    @incident_info ||= IncidentHelpers.incident_info(slack_helper, channel_id)
  end
end
