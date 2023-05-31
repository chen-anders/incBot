require_relative '../aws_helpers'

class AppMentionEventHandlers::CreateIncidentHandler < AppMentionEventHandlers::Base
  COMMAND_ARGS_REGEX = /(?<priority>(p|P)[1-5])?\s?(?<incident_name>.+)/

  def handle
    m = COMMAND_ARGS_REGEX.match(command_args.strip)
    if m
      incident_name = m['incident_name'] || ''
      if incident_name.size <= 4
        slack_helper.reply_in_thread(channel_id, ts, ":x: Incident name should be at least 5 chars long.")
        return
      end
      payload = {
        incident_name: incident_name,
        incident_commander: originating_user,
        incident_priority: (m['priority'] || 'unknown').downcase,
        user_id: originating_user,
      }
      if new_incident_handler_name
        slack_helper.reply_in_thread(channel_id, ts, "Creating incident for _#{incident_name}_")
        Lambda.invoke_function(new_incident_handler_name, payload)
      else
        slack_helper.post_message(user_id, ":x: New incident handler not properly configured.")
      end
    else
      slack_helper.reply_in_thread(channel_id, ts, ":x: Unable to parse command - usage: `create-incident [priority=P1/P2/P3/P4/P5 or leave blank for unknown] <incident-name>`")
    end
  end

  private

  def new_incident_handler_name
    ENV['NEW_INCIDENT_HANDLER_NAME']
  end
end
