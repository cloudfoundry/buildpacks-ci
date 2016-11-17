# encoding: utf-8
require 'json'
require 'net/http'
require 'net/https'
require 'uri'

class Concourse2Tracker
  def initialize(git_path:, api_token:, project_id:)
    @project_id = project_id
    @api_token = api_token
    @git_path = git_path
  end

  def story_id
    @story_id ||= begin
                    Dir.chdir(@git_path) do
                      commit = `git show`
                      match = commit.match(/\[#(\d+)\]/)
                      match[1] if match
                    end
                  end
  end

  def process!
    return unless story_id

    payload = { text: "Concourse pipeline passed: https://concourse.buildpacks-gcp.ci.cf-app.com/builds/#{ENV['BUILD_ID']}" }.to_json

    create_comment_uri = URI.parse("https://www.pivotaltracker.com/services/v5/projects/#{@project_id.to_i}/stories/#{story_id}/comments")

    request = Net::HTTP::Post.new(create_comment_uri)
    request.body = payload
    request['Content-Type'] = 'application/json'
    request['X-TrackerToken'] = @api_token

    response = Net::HTTP.start(create_comment_uri.hostname, create_comment_uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end
end
