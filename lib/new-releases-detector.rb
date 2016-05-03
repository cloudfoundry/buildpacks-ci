# encoding: utf-8
require 'json'
require 'octokit'
require 'open-uri'
require 'yaml'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require "#{buildpacks_ci_dir}/lib/slack-client"
require "#{buildpacks_ci_dir}/lib/tracker-client"
require "#{buildpacks_ci_dir}/lib/buildpack-dependency"

class NewReleasesDetector
  attr_reader :new_releases_dir
  attr_reader :dependency_tags

  def initialize(new_releases_dir)
    @new_releases_dir = new_releases_dir
    @dependency_tags = generate_dependency_tags(new_releases_dir)
  end

  def post_to_slack
    slack_client = SlackClient.new(
      ENV['SLACK_WEBHOOK'],
      ENV['SLACK_CHANNEL'],
      'dependency-notifier'
    )
    dependency_tags.each do |dependency, versions|
      versions.each do |version|
        new_dependency_version_output = "There is a new update to the *#{dependency}* dependency: version *#{version}*\n"
        slack_client.post_to_slack new_dependency_version_output
      end
    end
  end

  def post_to_tracker
    tracker_client = TrackerClient.new(
      ENV['TRACKER_API_TOKEN'],
      ENV['TRACKER_PROJECT_ID'],
      ENV['TRACKER_REQUESTER_ID'].to_i
    )
    dependency_tags.each do |dependency, versions|
      tracker_story_title = "Build and/or Include new releases: #{dependency} #{versions.join(', ')}"
      tracker_story_description = "We have #{versions.count} new releases for **#{dependency}**:\n**version #{versions.join(', ')}**\n See the google doc https://sites.google.com/a/pivotal.io/cloudfoundry-buildpacks/check-lists/adding-a-new-dependency-release-to-a-buildpack for info on building a new release binary and adding it to the buildpack manifest file."
      tracker_story_tasks = BuildpackDependency.for(dependency).map do |buildpack|
        "Update #{dependency} in #{buildpack}-buildpack"
      end

      tracker_client.post_to_tracker tracker_story_title, tracker_story_description, tracker_story_tasks
    end
  end

  private

  def configure_octokit
    Octokit.auto_paginate = true
    Octokit.configure do |c|
      c.login    = ENV.fetch('GITHUB_USERNAME')
      c.password = ENV.fetch('GITHUB_PASSWORD')
    end
  end

  def generate_dependency_tags(new_releases_dir)
    configure_octokit
    dependency_tags = {}

    tags.each do |current_dependency, get_tags|
      current_tags = get_tags.call

      filename = "#{new_releases_dir}/#{current_dependency}.yaml"
      previous_tags = if File.exist?(filename)
                        YAML.load_file(filename)
                      else
                        []
                      end

      diff_tags = current_tags - previous_tags

      if diff_tags.any?
        dependency_tags[current_dependency] = diff_tags
        File.write(filename, current_tags.to_yaml)
      else
        warn "There are no new updates to the *#{current_dependency}* dependency"
      end
    end
    dependency_tags
  end

  def tags
    @get_tags_functions = {
      composer:  -> { Octokit.tags('composer/composer').map(&:name) },
      go:        -> { Octokit.tags('golang/go').map(&:name).grep(/^go/) },
      godep:     -> { Octokit.tags('tools/godep').map(&:name).grep(/^v/) },
      httpd:     -> { Octokit.tags('apache/httpd').map(&:name).grep(/^2\./) },
      jruby:     -> { Octokit.tags('jruby/jruby').map(&:name).grep(/^(1|9)\./) },
      maven:     -> { Octokit.tags('apache/maven').map(&:name).grep(/^maven/) },
      nginx:     -> { Octokit.tags('nginx/nginx').map(&:name).grep(/^release/) },
      nodejs:    -> { Octokit.tags('nodejs/node').map(&:name).grep(/^v/) },
      openjdk:   -> { YAML.load(open('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml').read).keys },
      php:       -> { Octokit.tags('php/php-src').map(&:name).grep(/^php/) },
      python:    -> { JSON.parse(open('https://hg.python.org/cpython/json-tags').read)['tags'].map { |t| t['tag'] } },
      ruby:      -> { Octokit.tags('ruby/ruby').map(&:name).grep(/^v/) }
    }
  end
end
