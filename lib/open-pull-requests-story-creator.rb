#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"
require 'octokit'

class OpenPullRequestsStoryCreator
  def self.run!
    story_title = 'Review Open Pull Requests'
    story_description = 'Provide feedback for open pull requests in repos that the buildpacks team owns.'
    story_tasks = get_open_pull_requests_as_formatted_tasks

    create_tracker_story(story_title, story_description, story_tasks)
  end

  private

  def self.get_open_pull_requests_as_formatted_tasks
    Octokit.auto_paginate = true
    Octokit.configure do |c|
      c.login    = ENV.fetch('GITHUB_USERNAME')
      c.password = ENV.fetch('GITHUB_PASSWORD')
    end

    buildpack_repos = {
      'cloudfoundry' => ['go-buildpack',
                         'python-buildpack',
                         'ruby-buildpack',
                         'nodejs-buildpack',
                         'php-buildpack',
                         'staticfile-buildpack',
                         'binary-buildpack',
                         'buildpack-packager',
                         'machete',
                         'compile-extensions',
                         'buildpacks-ci',
                         'buildpack-releases',
                         'stacks'],
      'cloudfoundry-incubator' => ['buildpack_app_lifecycle']
    }

    story_tasks = []
    buildpack_repos.each do |org, repo_list|
      repo_list.each do |repo|
        repo_identifier = "#{org}/#{repo}"
        # Hit the API and determine if any open pull requests
        open_pull_requests = Octokit.pull_requests(repo_identifier, state: 'open')
        next if open_pull_requests.empty?
        open_pull_requests.each do |open_pull_request|
          puts "Found open PR in #{repo_identifier}: #{open_pull_request.title}"
          story_tasks << "#{repo_identifier}: #{open_pull_request.title} - #{open_pull_request.html_url}"
        end
      end
    end
    story_tasks
  end

  def self.create_tracker_story(story_title, story_description, story_tasks)
    tracker_client = TrackerClient.new(
      ENV['TRACKER_API_TOKEN'],
      ENV['TRACKER_PROJECT_ID'],
      ENV['TRACKER_REQUESTER_ID'].to_i
    )
    puts 'Creating Tracker story for reviewing open PRs'
    tracker_client.post_to_tracker story_title, story_description, story_tasks
    puts 'Successfully created tracker story reviewing open PRs'
  end
end
