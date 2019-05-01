class GithubIssueGenerator
  def initialize(octokit_client)
    @client = octokit_client
  end

  def run(title, description_file_path, repos_file_path)
    description = File.read(description_file_path).strip
    repos = File.read(repos_file_path).strip.split("\n")
    create_issues(title, description, repos)
  end

  def create_issues(title, description, repos)
    repos.each do |repo|
      @client.create_issue("cloudfoundry/#{repo}", title, description)
    end
  end
end