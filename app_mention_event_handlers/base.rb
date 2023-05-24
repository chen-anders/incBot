class AppMentionEventHandlers
  class Base
    ORANGE_COLOR = '#FFA500'.freeze
    GREEN_COLOR = '#008000'.freeze
    BLUE_COLOR = '#0818A8'.freeze

    def initialize(event_body, bot_user_id, command_args)
      @body = event_body
      @bot_user_id = bot_user_id
      @command_args = command_args
    end

    def handle
      raise NotImplementedError.new
    end

    private

    attr_reader :bot_user_id, :command_args

    def originating_user
      @body.dig('event', 'user')
    end

    def channel_id
      @body.dig('event', 'channel')
    end

    def message_text
      @body.dig('event', 'text')
    end

    def ts
      @body.dig('event', 'thread_ts') || @body.dig('event', 'ts')
    end

    def slack_helper
      SlackHelpers.new(Secrets.instance.slack_bot_oauth_token)
    end

    def pagerduty_helper
      @pagerduty_helper ||= PagerdutyHelpers.new(Secrets.instance.pagerduty_api_key)
    end

    def post_channel_message(channel_id, title:, message:, color: ORANGE_COLOR)
      slack_helper.post_channel_message(channel_id, message, title: title, color: color)
    end
  end
end
