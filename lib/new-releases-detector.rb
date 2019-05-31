# encoding: utf-8
require 'json'
require 'octokit'
require 'open-uri'
require 'yaml'
require 'git'
require 'nokogiri'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require "#{buildpacks_ci_dir}/lib/slack-client"
require "#{buildpacks_ci_dir}/lib/tracker-client"
require "#{buildpacks_ci_dir}/lib/buildpack-dependency"

class NewReleasesDetector
  attr_reader :new_releases_dir
  attr_reader :changed_dependencies, :unchanged_dependencies

  def initialize(new_releases_dir)
    @new_releases_dir = new_releases_dir
    @changed_dependencies, @unchanged_dependencies = generate_dependency_tags(new_releases_dir)

    print_log
  end

  def post_to_slack
    slack_clients = {}

    slack_clients['buildpacks'] = SlackClient.new(
      ENV.fetch('BUILDPACKS_SLACK_WEBHOOK'),
      ENV.fetch('BUILDPACKS_SLACK_CHANNEL'),
      'dependency-notifier'
    )

    slack_clients['capi'] = SlackClient.new(
      ENV.fetch('CAPI_SLACK_WEBHOOK'),
      ENV.fetch('CAPI_SLACK_CHANNEL'),
      'dependency-notifier'
    )

    changed_dependencies.each do |dependency, versions|
      new_dependency_version_output = "There is a new version of *#{dependency}* available: *#{versions.join(', ')}*"
      slack_clients['buildpacks'].post_to_slack new_dependency_version_output
      slack_clients['capi'].post_to_slack new_dependency_version_output if notify_capi?(dependency, versions)
    end
  end

  def notify_capi?(dependency, versions)
    return false if dependency != :nginx

    notify = false
    versions.each do |ver|
      major, minor, _ = ver.split('.')
      notify = true if major == '1' && minor == '11'
    end
    notify
  end

  def post_to_tracker
    tracker_clients = {}

    tracker_clients['buildpacks'] = TrackerClient.new(
      ENV.fetch('TRACKER_API_TOKEN'),
      ENV.fetch('BUILDPACKS_TRACKER_PROJECT_ID'),
      ENV.fetch('TRACKER_REQUESTER_ID').to_i
    )

    tracker_clients['capi'] = TrackerClient.new(
      ENV.fetch('TRACKER_API_TOKEN'),
      ENV.fetch('CAPI_TRACKER_PROJECT_ID'),
      ENV.fetch('TRACKER_REQUESTER_ID').to_i
    )

    changed_dependencies.each do |dependency, versions|
      story_info = buildpacks_tracker_story_info(dependency, versions)

      tracker_clients['buildpacks'].post_to_tracker(name: story_info[:name],
                                     description: story_info[:description],
                                     tasks: story_info[:tasks],
                                     labels: story_info[:labels],
                                     point_value: 0)
      if notify_capi?(dependency, versions)
        story_info = capi_tracker_story_info(dependency, versions)

        tracker_clients['capi'].post_to_tracker(name: story_info[:name],
                                       description: story_info[:description],
                                       tasks: story_info[:tasks],
                                       labels: story_info[:labels],
                                       point_value: 1)
      end
    end
  end

  private

  def capi_tracker_story_info(dependency, versions)
    name = "New version(s) of #{dependency}: #{versions.join(', ')}"
    description =  "There are #{versions.count} new version(s) of **#{dependency}** available: #{versions.join(', ')}"

    {
      name: name,
      description: description,
      tasks: [],
      labels: []
    }
  end

  def buildpacks_tracker_story_info(dependency,versions)
    name = "Build and/or Include new releases: #{dependency} #{versions.join(', ')}"
    description = "We have #{versions.count} new releases for **#{dependency}**:\n**version #{versions.join(', ')}**\n\nThis dependency is NOT handled by the dependency-builds pipeline.\n"

    buildpack_names = BuildpackDependency.for(dependency)
    tasks = buildpack_names.map do |buildpack|
      "Verify #{dependency} is updated in #{buildpack}-buildpack if version is supported"
    end
    labels = buildpack_names.map do |buildpack|
      buildpack.to_s
    end

    case dependency
    when :maven
      description += 'Update the jruby recipe in the binary-builder repo.'
    when :openjdk
      description += 'Update the jruby recipe in the binary-builder repo.'
    when :apr
      description += 'Update the httpd recipe in the binary-builder repo.'
    when :apr_util
      description += 'Update the httpd recipe in the binary-builder repo.'
    end

    {
      name: name,
      description: description,
      tasks: tasks,
      labels: labels
    }
  end

  def configure_octokit
    Octokit.auto_paginate = true
    Octokit.configure do |c|
      c.login    = ENV.fetch('GITHUB_USERNAME')
      c.password = ENV.fetch('GITHUB_PASSWORD')
    end
  end

  def print_log
    if changed_dependencies.any?
      warn "NEW DEPENDENCIES FOUND:\n\n"

      changed_dependencies.each do |dependency, versions|
        warn "- #{dependency}: #{versions.join(', ')}"
      end
    end

    if unchanged_dependencies.any?
      warn "\nNo Updates Needed:\n\n"

      unchanged_dependencies.each do |dependency|
        warn "- #{dependency}"
      end
    end
  end

  def generate_dependency_tags(new_releases_dir)
    configure_octokit
    dependency_tags = {}
    unchanged_dependencies = []

    tags.each do |current_dependency, get_tags|
      current_tags = get_tags.call

      filename = "#{new_releases_dir}/#{current_dependency}.yml"
      filename_diff = "#{new_releases_dir}/#{current_dependency}-new.yml"
      previous_tags = if File.exist?(filename)
                        YAML.load_file(filename)
                      else
                        []
                      end

      diff_tags = current_tags - previous_tags

      if diff_tags.any?
        dependency_tags[current_dependency] = diff_tags
        File.write(filename, current_tags.to_yaml)
        File.write(filename_diff, diff_tags.to_yaml)
      else
        unchanged_dependencies << current_dependency
      end
    end

    return dependency_tags, unchanged_dependencies
  end

  def tags
    @get_tags_functions = {
      apr:             -> { Nokogiri::HTML.parse(open('https://apr.apache.org/download.cgi')).css('a[name=apr1] strong').map{|a|a.text.gsub(/APR\s+(\S+).*/, '\1')} },
      apr_util:        -> { Nokogiri::HTML.parse(open('https://apr.apache.org/download.cgi')).css('a[name=aprutil1] strong').map{|a|a.text.gsub(/APR\-util\s+(\S+).*/, '\1')} },
      maven:           -> {
        history = Nokogiri::HTML(open('https://maven.apache.org/docs/history.html')).text
        Octokit.tags('apache/maven').map(&:name).grep(/^maven/).map{|s| s.gsub(/^maven\-/,'')}.select{|v| history.include?(v) && v !~ /alpha|beta/}
      },
      openjdk:         -> { YAML.load(open('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml').read).keys },
    }
  end
end
