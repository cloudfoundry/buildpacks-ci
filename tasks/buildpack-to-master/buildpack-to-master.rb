#!/usr/bin/env ruby
require 'octokit'
require_relative '../../lib/git-client.rb'

class BuildpackToMaster
  def initialize(github_access_token, github_repo, github_status_context, github_status_description, pipeline_uri)
    @github_access_token = github_access_token
    @github_repo = github_repo
    @github_status_context = github_status_context
    @github_status_description = github_status_description
    @pipeline_uri = pipeline_uri
  end

  def run
    Octokit.configure do |c|
      c.access_token = @github_access_token
    end

    @prev_sha = GitClient.get_commit_sha('repo', 1).chomp
    @sha = GitClient.get_commit_sha('repo', 0).chomp

    puts "SHA: #{@sha} :: PrevSHA: #{@prev_sha}"

    if has_statuses? && no_other_changes?
      Octokit.create_status(
        @github_repo,
        @sha,
        'success',
        context: @github_status_context,
        description: @github_status_description,
        target_url: @pipeline_uri
      )

      Octokit.update_branch(
        @github_repo,
        'master',
        @sha
      )
    else
      raise "Unsafe file changes"
    end
  end

  private

  def has_statuses?
    statuses = Octokit.list_statuses(
      @github_repo,
      @prev_sha
    )
    stats = statuses.map { |s| s[:context] }
    if @github_repo =~ /(hwc|apt)-buildpack/ && stats.include?('buildpacks-ci/edge-develop')
      return true
    elsif stats.include?('buildpacks-ci/lts-develop') && stats.include?('buildpacks-ci/edge-develop')
      return true
    end
    puts "Missing statuses. Statuses present are #{stats.inspect}."
    return false
  end

  def no_other_changes?
    files = GitClient.last_commit_files('repo').split("\n").sort
    puts "Files changes in commit are #{files.inspect}."
    return files == ["CHANGELOG", "VERSION"]
  end
end




