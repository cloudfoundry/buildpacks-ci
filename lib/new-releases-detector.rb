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
    slack_client = SlackClient.new(
      ENV['SLACK_WEBHOOK'],
      ENV['SLACK_CHANNEL'],
      'dependency-notifier'
    )
    changed_dependencies.each do |dependency, versions|
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
    changed_dependencies.each do |dependency, versions|
      tracker_story_name = "Build and/or Include new releases: #{dependency} #{versions.join(', ')}"
      tracker_story_description = "We have #{versions.count} new releases for **#{dependency}**:\n**version #{versions.join(', ')}**\n See the documentation at http://docs.cloudfoundry.org/buildpacks/upgrading_dependency_versions.html for info on building a new release binary and adding it to the buildpack manifest file."

      buildpack_names = BuildpackDependency.for(dependency)
      tracker_story_tasks = buildpack_names.map do |buildpack|
        "Update #{dependency} in #{buildpack}-buildpack"
      end
      tracker_story_labels = buildpack_names.map do |buildpack|
        buildpack.to_s
      end

      if dependency == :dotnet
        tracker_story_tasks.push 'Remove any dotnet versions MS no longer supports'
      end

      tracker_client.post_to_tracker(name: tracker_story_name,
                                     description: tracker_story_description,
                                     tasks: tracker_story_tasks,
                                     labels: tracker_story_labels,
                                     point_value: 1)
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
      current_tags = massage_version(get_tags.call, current_dependency)

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
      bundler:         -> { Octokit.tags('bundler/bundler').map(&:name).grep(/^v/) },
      bower:           -> { JSON.parse(open('https://registry.npmjs.org/bower').read)['versions'].keys },
      composer:        -> { Octokit.tags('composer/composer').map(&:name) },
      dotnet:          -> { Octokit.tags('dotnet/cli').map(&:name).grep(/^v/) },
      glide:           -> { Octokit.tags('Masterminds/glide').map(&:name).grep(/^v/) },
      go:              -> { Octokit.tags('golang/go').map(&:name).grep(/^go/) },
      godep:           -> { Octokit.tags('tools/godep').map(&:name).grep(/^v/) },
      httpd:           -> { Octokit.tags('apache/httpd').map(&:name).grep(/^2\./) },
      jruby:           -> { Octokit.tags('jruby/jruby').map(&:name).grep(/^(1|9)\./) },
      maven:           -> { Octokit.tags('apache/maven').map(&:name).grep(/^maven/) },
      nginx:           -> { Octokit.tags('nginx/nginx').map(&:name).grep(/^release/) },
      node:            -> { JSON.parse(open('https://nodejs.org/dist/index.json').read).map{|d| d['version']} },
      openjdk:         -> { YAML.load(open('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml').read).keys },
      php:             -> { Octokit.tags('php/php-src').map(&:name).grep(/^php/) },
      python:          -> { JSON.parse(open('https://hg.python.org/cpython/json-tags').read)['tags'].map { |t| t['tag'] } },
      ruby:            -> { Octokit.tags('ruby/ruby').map(&:name).grep(/^v/) },
      libunwind:       -> { Git.ls_remote('http://git.savannah.gnu.org/cgit/libunwind.git')['tags'].keys },
      miniconda:       -> { Nokogiri::HTML.parse(open('https://repo.continuum.io/miniconda/').read).css('table tr td a').map {|link| link['href']} }
    }
  end

  # take the list of tags and format the version so it matches
  # the version in the buildpack manifest.yml. This way, the version format
  # is consistent throughout the whole pipeline.
  def massage_version(tags,dependency)
    case dependency
    when :miniconda
      versions_if_found = tags.map do |link|
        match = link.match(/-((?<ver>\d+\.\d+\.\d+))-Linux-x86_64/)

        match['ver'] unless match.nil?
      end

      versions_if_found.compact.uniq.sort
    when :node
      tags.map { |tag| tag.gsub(/v/,"")}
    when :nginx
      tags.map { |tag| tag.gsub('release-', '')}
    else
      tags
    end
  end
end
