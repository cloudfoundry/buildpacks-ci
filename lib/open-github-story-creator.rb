#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"
require 'octokit'

class OpenGithubStoryCreator
  def self.create_pull_requests_story
    story_name = 'Review Open Pull Requests'
    story_description = 'Provide feedback for open pull requests in repos that the buildpacks team owns.'
    story_tasks = get_open_pull_requests_as_formatted_tasks
    labels = %w(maintenance)
    point_value = 1

    puts 'Creating Tracker story for reviewing open PRs'
    create_tracker_story(story_name, story_description, story_tasks, point_value, labels)
    puts 'Successfully created tracker story reviewing open PRs'
  end

  def self.create_issues_story
    story_name = 'Review Open Issues'
    story_description = 'Provide feedback for open issues in repos that the buildpacks team owns.'
    story_tasks = get_open_issues_as_formatted_tasks
    labels = %w(maintenance)
    point_value = 1

    puts 'Creating Tracker story for reviewing open issues'
    create_tracker_story(story_name, story_description, story_tasks, point_value, labels)
    puts 'Successfully created tracker story reviewing open issues'
  end

  private

  @@buildpack_repos = {
    'cloudfoundry' => ['go-buildpack',
                       'python-buildpack',
                       'ruby-buildpack',
                       'nodejs-buildpack',
                       'php-buildpack',
                       'staticfile-buildpack',
                       'binary-buildpack',
                       'dotnet-core-buildpack',
                       'buildpack-packager',
                       'machete',
                       'compile-extensions',
                       'binary-builder',
                       'buildpacks-ci',
                       'buildpack-releases',
                       'cflinuxfs2-rootfs-release',
                       'brats',
                       'stacks',
                       'go-buildpack-release',
                       'ruby-buildpack-release',
                       'python-buildpack-release',
                       'php-buildpack-release',
                       'nodejs-buildpack-release',
                       'staticfile-buildpack-release',
                       'binary-buildpack-release',
                       'java-offline-buildpack-release',
                       'java-buildpack-release'],
    'cloudfoundry-incubator' => ['multi-buildpack'],
    'pivotal-cf-experimental' => ['stacks-release', 'concourse-filter', 'new_version_resource']
  }

  def self.configure_octokit
    Octokit.auto_paginate = true
    Octokit.configure do |c|
      c.login    = ENV.fetch('GITHUB_USERNAME')
      c.password = ENV.fetch('GITHUB_PASSWORD')
    end
  end

  def self.get_open_pull_requests_as_formatted_tasks
    configure_octokit

    story_tasks = []
    @@buildpack_repos.each do |org, repo_list|
      repo_list.each do |repo|
        repo_identifier = "#{org}/#{repo}"
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

  def self.get_open_issues_as_formatted_tasks
    configure_octokit

    story_tasks = []
    @@buildpack_repos.each do |org, repo_list|
      repo_list.each do |repo|
        repo_identifier = "#{org}/#{repo}"
        open_issues = Octokit.list_issues(repo_identifier, state: 'open')
        next if open_issues.empty?
        open_issues.each do |open_issue|
          # do not include pull requests
          next unless open_issue.pull_request.nil?
          puts "Found open issue in #{repo_identifier}: #{open_issue.title}"
          story_tasks << "#{repo_identifier}: #{open_issue.title} - #{open_issue.html_url}"
        end
      end
    end
    story_tasks
  end

  def self.create_tracker_story(story_name, story_description, story_tasks, point_value, labels)
    tracker_client = TrackerClient.new(
      ENV['TRACKER_API_TOKEN'],
      ENV['TRACKER_PROJECT_ID'],
      ENV['TRACKER_REQUESTER_ID'].to_i
    )
    tracker_client.post_to_tracker(name: story_name, description: story_description, tasks: story_tasks, point_value: point_value, labels: labels)
  end
end
