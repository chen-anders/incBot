require 'net/http'
require 'json'

class PagerdutyHelpers
  def self.format_oncall_message(team_name, oncalls)
    oncall_text = oncalls.map do |oncall|
      escalation_level = escalation_level_names(oncall.dig('escalation_level'))
      until_str = (oncall.dig('end') ? "_(until #{oncall.dig('end')})_" : "")
      "#{escalation_level}: #{oncall.dig('user', 'summary')} #{until_str}".strip
    end
    <<~EOM
      :pager: *Currently oncall for `#{team_name}`*: :pager:
      #{oncall_text.join("\n")}
    EOM
  end

  def self.escalation_level_names(escalation_level)
    case escalation_level
    when 1
      "Primary"
    when 2
      "Secondary"
    else
      "Level #{escalation_level}"
    end
  end

  class PagerDutyRequestError < StandardError; end
  class NoEscalationPolicyFound < StandardError; end
  class CreateIncidentError < StandardError; end
  API_ENDPOINT = 'https://api.pagerduty.com'.freeze
  SERVICE_TEAM_MAPPINGS_JSON = 'pagerduty-config.json'.freeze
  def initialize(api_key)
    @api_key = api_key
    @service_team_mappings = load_team_mappings
  end

  def get_current_oncall_for_team(oncall_team_name)
    service_id = get_service_from_team_name(oncall_team_name)
    if service_id
      get_oncalls(service_id)
    else
      raise NoEscalationPolicyFound.new("No escalation policy found.")
    end
  end

  def get_service_from_team_name(team_name)
    @service_team_mappings[normalize_team_name(team_name)]
  end

  def create_incident(oncall_team_name, title, description)
    service_id = get_service_from_team_name(oncall_team_name)
    if service_id
      incident_params = {
        incident: {
          type: 'incident',
          title: title,
          service: { type: 'service_reference', id: service_id },
          urgency: 'high',
          body: { type: 'incident_body', details: description }
        }
      }
      resp = make_post_request('incidents', incident_params)
      if resp.code.to_i == 201
        parsed_resp = JSON.parse(resp.body)
        created_incident = parsed_resp.dig('incident')
        {
          html_url: created_incident.dig('html_url'),
          incident_number: created_incident.dig('incident_number'),
          title: created_incident.dig('title'),
          assignments: created_incident.dig('assignments')
        }
      else
        raise CreateIncidentError.new("error (#{resp.code}) - #{resp.body}")
      end
    else
      raise CreateIncidentError.new("No service ID found for `#{oncall_team_name}`.")
    end
  end

  private

  def get_service_escalation_policy_id(service_id)
    resp = make_get_request("services/#{service_id}")
    if resp.code.to_i == 200
      JSON.parse(resp.body).dig('service', 'escalation_policy', 'id')
    else
      STDERR.puts "PagerDuty error: #{resp.code} - #{resp.body}"
      raise PagerDutyRequestError.new("error (#{resp.code}) - #{resp.body}")
    end
  end

  def get_oncalls(service_id)
    escalation_policy_id = get_service_escalation_policy_id(service_id)
    raise PagerDutyRequestError.new("error: no escalation policy found for service ID: #{service_id}") unless escalation_policy_id
    query_params = {
      "escalation_policy_ids[]" => escalation_policy_id,
      "time_zone" => "America/New_York"
    }
    resp = make_get_request('oncalls', query_params)
    if resp.code.to_i == 200
      JSON.parse(resp.body).dig('oncalls')
    else
      STDERR.puts "PagerDuty error: #{resp.code} - #{resp.body}"
      raise PagerDutyRequestError.new("error (#{resp.code}) - #{resp.body}")
    end
  end

  def make_get_request(resource, query_params = {})
    encoded_query_params = (query_params.empty? ? '' : "?#{URI.encode_www_form(query_params)}")
    uri = URI.parse("#{API_ENDPOINT}/#{resource}#{encoded_query_params}".strip)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri.request_uri)
    request = set_request_headers(request)
    http.request(request)
  end

  def make_post_request(resource, body = {})
    uri = URI.parse("#{API_ENDPOINT}/#{resource}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request =  Net::HTTP::Post.new(uri.request_uri)
    request = set_request_headers(request)
    request.body = body.to_json
    http.request(request)
  end

  def set_request_headers(request)
    request['Authorization'] = "Token token=#{@api_key}"
    request['Content-Type'] = "application/json"
    request['Accept'] = 'application/vnd.pagerduty+json;version=2'
    request
  end

  def load_team_mappings
    if File.exists?(SERVICE_TEAM_MAPPINGS_JSON)
      mappings = JSON.parse(File.read(SERVICE_TEAM_MAPPINGS_JSON))
      result = {}
      mappings.each do |team|
        team_name = team.dig('name')
        team_aliases = team.dig('aliases') || []
        service_id = team.dig('service_id')
        next unless team_name && service_id
        result[normalize_team_name(team_name)] = service_id
        team_aliases.each do |team_alias|
          result[normalize_team_name(team_alias)] = service_id
        end
      end
      result
    else
      {}
    end
  end

  def normalize_team_name(name)
    (name || '').downcase.gsub(/[_-]*/, '')
  end
end
