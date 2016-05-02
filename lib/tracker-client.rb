# encoding: utf-8
require 'net/http'
require 'net/https'
require 'uri'
require 'json'

class TrackerClient
  def initialize(key, project, requester_id)
    @api_key = key
    @project_id = project
    @requester_id = requester_id
    raise 'invalid api key for tracker' unless validate_string @api_key
    raise 'invalid project id for tracker' unless validate_string @project_id
    raise 'invalid requester id for tracker' unless validate_number @requester_id
  end

  def post_to_tracker(name, description, tasks = [], point_value = nil)
    name = name.to_s
    raise 'requested tracker story has no title' unless validate_string name
    raise 'requested tracker story has no description' unless validate_string description

    task_api_objs = tasks.map { |task| { description: task } }

    payload = {
      name: name,
      description: description,
      requested_by_id: @requester_id,
      tasks: task_api_objs,
    }

    payload[:estimate] = point_value if point_value

    create_story_uri = URI.parse("https://www.pivotaltracker.com/services/v5/projects/#{@project_id}/stories")

    request = Net::HTTP::Post.new(create_story_uri)
    request.body = payload.to_json
    request['Content-Type'] = 'application/json'
    request['X-TrackerToken'] = @api_key

    response = Net::HTTP.start(create_story_uri.hostname, create_story_uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    raise response.message if response.code != '200'

    response
  end

  private

  def validate_string(cred)
    !(cred.nil? || !cred.is_a?(String) || cred.empty?)
  end

  def validate_number(cred)
    !(cred.nil? || !cred.is_a?(Numeric))
  end
end
