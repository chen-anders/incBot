require_relative '../pagerduty_helpers'

class AppMentionEventHandlers::OncallTeamsHandler < AppMentionEventHandlers::Base
  def handle
    oncall_teams = PagerdutyHelpers.get_all_oncall_teams
    msg = oncall_teams.map do |team_name, team_aliases|
      aliases = if team_aliases.any?
        "_(aliases: #{team_aliases.join(", ")})_"
      else
        ''
      end
      "- *#{team_name}* #{aliases}".strip
    end.join("\n")
    slack_helper.reply_in_thread(channel_id, ts, ":pager: *List of oncall teams:* :pager: \n #{msg}")
  end
end
