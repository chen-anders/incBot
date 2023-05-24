require_relative '../pagerduty_helpers'

class AppMentionEventHandlers::PageHandler < AppMentionEventHandlers::Base
  def handle
    oncall_team_name = command_args.split(' ').first || ''
    return slack_helper.reply_in_thread(channel_id, ts, ":x: No oncall team name entered.") if oncall_team_name == ''
    title = command_args.sub(oncall_team_name, '').strip || ''
    return slack_helper.reply_in_thread(channel_id, ts, ":x: No incident description entered.") if title == ''
    begin
      title_with_channel_name = "[#{channel_name}] #{title}"
      incident = pagerduty_helper.create_incident(oncall_team_name, title_with_channel_name, incident_description(title))
      post_created_incident_details(oncall_team_name, incident)
    rescue PagerdutyHelpers::CreateIncidentError => e
      slack_helper.reply_in_thread(channel_id, ts, ":x: Unable to page #{oncall_team_name}: #{e.message}")
    end
  end

  private

  def incident_description(title)
    <<~EOM
      #{title}

      Slack Channel: #{channel_name}
      Slack Link: #{slack_link}
    EOM
  end

  def channel_name
    @channel_name ||= begin
      resp = slack_helper.channel_info(channel_id)
      if resp.code.to_i == 200
        parsed_resp = JSON.parse(resp.body)
        "##{parsed_resp.dig('channel', 'name')}"
      else
        "(unable to get channel name)"
      end
    end
  end

  def slack_link
    message_ts = @body.dig('event', 'ts')
    resp = slack_helper.get_message_permalink(channel_id, message_ts)
    if resp.code.to_i == 200
      parsed_resp = JSON.parse(resp.body)
      parsed_resp.dig('permalink')
    else
      '(unable to generate permalink)'
    end
  end

  def post_created_incident_details(oncall_team_name, incident)
    assignments_text = incident[:assignments].map { |assignment| assignment.dig('assignee', 'summary') }.join(', ')
    details = <<~EOM
      :pager: :loud_sound: Sent a <#{incident[:html_url]}|page> to oncall responder on #{oncall_team_name} with: _#{incident[:title]}_

      Page was assigned to: #{assignments_text}
    EOM
    slack_helper.reply_in_thread(channel_id, ts, details)
  end
end
