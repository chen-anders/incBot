class AppMentionEventHandlers::UpdateIncidentHandler < AppMentionEventHandlers::Base
  ICON = ":zap:".freeze
  def handle
    return IncidentHelpers.post_not_in_incident_channel_message(slack_helper, channel_id, ts) unless IncidentHelpers.incident_channel?(incident_info)
    update_text = command_args
    if IncidentHelpers.incident_broadcast_channel_id
      post_channel_message(
        IncidentHelpers.incident_broadcast_channel_id,
        title: "#{ICON} Incident update: #{incident_info[:incident_name]} #{ICON}",
        message: "*Channel*: <##{channel_id}>\n*Status*: #{incident_info[:status]}\nUpdate from <@#{originating_user}>: #{update_text}",
        color: ORANGE_COLOR
      )
      post_channel_message(
        channel_id,
        title: "#{ICON} Update posted to <##{IncidentHelpers.incident_broadcast_channel_id}>",
        message: "<@#{originating_user}>: #{update_text}",
        color: ORANGE_COLOR
      )
    else
      slack_helper.reply_in_thread(channel_id, ts, ":x: No incident broadcast channel configured to post incident update.")
    end
  end

  def incident_info
    @incident_info ||= IncidentHelpers.incident_info(slack_helper, channel_id)
  end
end
