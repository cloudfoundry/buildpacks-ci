require 'rest-client'
require 'json'

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

    RestClient.post(
      "https://www.pivotracker.com/services/v5/projects/#{@project_id}/stories/#{story_id}/comments",
      {text: "Concourse pipeline passed: https://buildpacks.ci.cf-app.com/builds/#{ENV['BUILD_ID']}"}.to_json,
      :content_type => :json,
      'X-TrackerToken' => @api_token
    )
  end

end
