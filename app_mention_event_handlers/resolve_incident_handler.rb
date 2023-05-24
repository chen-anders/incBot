class AppMentionEventHandlers::ResolveIncidentHandler < AppMentionEventHandlers::Base
  ICON = ':white_check_mark:'.freeze

  def handle
    return IncidentHelpers.post_not_in_incident_channel_message(slack_helper, channel_id, ts) unless IncidentHelpers.incident_channel?(incident_info)
    resolution_text = (command_args == '' ? 'Incident is now resolved.' : command_args)
    if IncidentHelpers.incident_broadcast_channel_id
      post_channel_message(
        IncidentHelpers.incident_broadcast_channel_id,
        title: "#{ICON} Incident Resolved: #{incident_info[:incident_name]} #{ICON}",
        message: "*Channel*: <##{channel_id}>\n*Status*: Resolved\nUpdate from <@#{originating_user}>: #{resolution_text}",
        color: GREEN_COLOR
      )
      post_channel_message(
        channel_id,
        title: "#{ICON} Incident resolution status posted to <##{IncidentHelpers.incident_broadcast_channel_id}>",
        message: "<@#{originating_user}>: #{resolution_text}",
        color: GREEN_COLOR
      )
    else
      slack_helper.reply_in_thread(channel_id, ts, ":x: No incident broadcast channel configured to post incident update.")
    end
    update_channel_topic
  end

  def update_channel_topic
    topic = IncidentHelpers.serialize_topic(incident_info.merge({ status: 'Resolved' }))
    slack_helper.set_channel_topic(channel_id, topic)
    @incident_info = incident_info.merge({ status: 'Resolved' })
  end

  def incident_info
    @incident_info ||= IncidentHelpers.incident_info(slack_helper, channel_id)
  end
end
