require 'openssl'
require 'uri'
require 'net/http'
require 'json'

class SlackHelpers
  def self.verify_signature(signature, timestamp, signing_secret, body)
    # Construct the string to sign
    basestring = "v0:#{timestamp}:#{body}"
    # Calculate the signature
    hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), signing_secret, basestring)
    expected_signature = "v0=#{hmac}"
    # Compare the calculated signature with the received signature
    result = secure_compare(signature, expected_signature)
    unless result
      STDERR.puts "Signature mismatch: Calculated #{signature}, but expected #{expected_signature}!"
    end
    result
  end

  def self.secure_compare(a, b)
    return false unless a.bytesize == b.bytesize

    l = a.unpack("C#{a.bytesize}")

    res = 0
    b.each_byte { |byte| res |= byte ^ l.shift }
    res == 0
  end

  def initialize(token)
    @token = token
  end

  def whoami
    resp = make_post_request('auth.test')
    body = JSON.parse(resp.body)
    body.dig('user_id')
  end

  def present_modal(modal_hash)
    make_post_request('views.open', modal_hash)
  end

  def create_channel(channel_name, private: false)
    channel_obj = {
      name: channel_name,
      is_private: private
    }
    make_post_request('conversations.create', channel_obj)
  end

  def channel_info(channel_id)
    make_get_request('conversations.info', {channel: channel_id})
  end

  def invite_users(channel_id, user_ids)
    return if user_ids.empty?
    params = { channel: channel_id, users: user_ids.uniq.join(',')}
    make_post_request('conversations.invite', params)
  end

  def post_channel_message(channel_id, text, title: nil, color: '#326de5')
    params = { channel: channel_id }.merge(attachment_text(text, title: title, color: color))
    make_post_request('chat.postMessage', params)
  end

  def post_message(channel_id, text)
    params = { channel: channel_id }.merge(markdown_message_block(text))
    make_post_request('chat.postMessage', params)
  end

  def post_blocks(channel_id, blocks)
    params = { channel: channel_id, blocks: blocks }
    make_post_request('chat.postMessage', params)
  end

  def reply_in_thread(channel_id, ts, text)
    params = { channel: channel_id, thread_ts: ts }.merge(markdown_message_block(text))
    make_post_request('chat.postMessage', params)
  end

  def set_channel_topic(channel_id, topic)
    params = { channel: channel_id, topic: topic }
    make_post_request('conversations.setTopic', params)
  end

  private

  def attachment_text(text, title: nil, color: '#326de5')
    {
      attachments: [
        {
          title: title,
          text: text,
          color: color
        }.compact
      ]
    }
  end

  def markdown_message_block(text)
    {
      blocks: [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: text
          }
        }
      ]
    }
  end

  def make_get_request(action, query_params)
    encoded_query_params = URI.encode_www_form(query_params)
    uri = URI.parse("https://slack.com/api/#{action}?#{encoded_query_params}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@token}"

    http.request(request)
  end

  def make_post_request(action, body = {})
    uri = URI.parse("https://slack.com/api/#{action}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path,
      {'Content-Type' => 'application/json', 'Authorization' => "Bearer #{@token}"})

    request.body = body.to_json

    http.request(request)
  end
end
