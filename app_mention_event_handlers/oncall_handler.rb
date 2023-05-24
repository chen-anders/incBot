require_relative '../pagerduty_helpers'

class AppMentionEventHandlers::OncallHandler < AppMentionEventHandlers::Base
  def handle
    oncall_team_name = command_args.split(' ').first || ''
    return slack_helper.reply_in_thread(channel_id, ts, ":x: No oncall team name entered.") if oncall_team_name == ''
    begin
      oncalls = pagerduty_helper.get_current_oncall_for_team(oncall_team_name).sort { |a,b| a.dig('escalation_level') <=> b.dig('escalation_level') }
      if oncalls.any?
        slack_helper.reply_in_thread(channel_id, ts, PagerdutyHelpers.format_oncall_message(oncall_team_name, oncalls))
      else
        slack_helper.reply_in_thread(channel_id, ts, "No oncall was found for #{oncall_team_name}.")
      end
    rescue PagerdutyHelpers::NoEscalationPolicyFound
      slack_helper.reply_in_thread(channel_id, ts, ":x: No escalation policy found for #{oncall_team_name}.")
    rescue PagerdutyHelpers::PagerDutyRequestError => e
      slack_helper.reply_in_thread(channel_id, ts, ":x: Error retrieving current oncall for #{oncall_team_name}: #{e.message}")
    end
  end
end
