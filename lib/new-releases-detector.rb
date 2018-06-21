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
                                     point_value: 1)
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
    description = "We have #{versions.count} new releases for **#{dependency}**:\n**version #{versions.join(', ')}**\n\nSee the documentation at http://docs.cloudfoundry.org/buildpacks/upgrading_dependency_versions.html for info on building a new release binary and adding it to the buildpack manifest file."

    buildpack_names = BuildpackDependency.for(dependency)
    tasks = buildpack_names.map do |buildpack|
      "Verify #{dependency} is updated in #{buildpack}-buildpack if version is supported"
    end
    labels = buildpack_names.map do |buildpack|
      buildpack.to_s
    end

    if dependency == :go
      tasks.push 'Update go-version.yml in binary-builder repo'
    elsif dependency == :libunwind
      description += <<~HEREDOC
                     Dockerfile.libunwind
                     ```
                     FROM cloudfoundry/$CF_STACK

                     RUN curl -sSL http://download.savannah.gnu.org/releases/libunwind/libunwind-${LIBUNWIND_VERSION}.tar.gz | tar zxfv - -C /usr/local/src \
                           && cd /usr/local/src/libunwind-${LIBUNWIND_VERSION} \
                           && ./configure \
                           && make \
                           && make install \
                           && rm -rf /usr/local/src/libunwind-${LIBUNWIND_VERSION}
                     ```

                     ```
                     export CF_STACK=cflinuxfs2
                     export LIBUNWIND_VERSION=1.2
                     cat Dockerfile.libunwind | envsubst | docker build -t libunwind-${CF_STACK}-${LIBUNWIND_VERSION} -
                     docker run -v /somehostdir:/built --rm libunwind-${CF_STACK}-${LIBUNWIND_VERSION} /bin/bash -c "cd /usr/local && tar czf /built/libunwind-${CF_STACK}-${LIBUNWIND_VERSION}.tar.gz ./include/*unwind* ./lib/libunwind*"
                     ```
                     HEREDOC
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
      apr:             -> { Nokogiri::HTML.parse(open('https://apr.apache.org/download.cgi')).css('a[name=apr1] strong').map{|a|a.text.gsub(/APR\s+(\S+).*/, '\1')} },
      apr_util:        -> { Nokogiri::HTML.parse(open('https://apr.apache.org/download.cgi')).css('a[name=aprutil1] strong').map{|a|a.text.gsub(/APR\-util\s+(\S+).*/, '\1')} },
      jruby:           -> { Octokit.tags('jruby/jruby').map(&:name).grep(/^(1|9)\./) },
      libunwind:       -> { Octokit.releases('libunwind/libunwind').map(&:tag_name) },
      maven:           -> {
        history = Nokogiri::HTML(open('https://maven.apache.org/docs/history.html')).text
        Octokit.tags('apache/maven').map(&:name).grep(/^maven/).map{|s| s.gsub(/^maven\-/,'')}.select{|v| history.include?(v) && v !~ /alpha|beta/}
      },
      miniconda:       -> { Nokogiri::HTML.parse(open('https://repo.continuum.io/miniconda/').read).css('table tr td a').map {|link| link['href']} },
      newrelic:        -> { Nokogiri::HTML.parse(open('https://download.newrelic.com/php_agent/archive/')).css('table td a').map{|link| link['href']} },
      nginx:           -> { Octokit.tags('nginx/nginx').map(&:name).grep(/^release/) },
      openjdk:         -> { YAML.load(open('https://download.run.pivotal.io/openjdk/trusty/x86_64/index.yml').read).keys },
      php:             -> { Octokit.tags('php/php-src').map(&:name).grep(/^php/) },
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
    when :newrelic
      versions_if_found = tags.map do |link|
        match = link.match(/((?<ver>\d+\.\d+\.\d+\.\d+))/)

        match['ver'] unless match.nil?
      end

      versions_if_found.compact.uniq.sort
    when :bundler, :rubygems
      tags.map { |tag| tag.gsub(/v/,"")}
    when :node
      tags.map { |tag| tag.gsub(/v/,"")}
    when :nginx
      tags.map { |tag| tag.gsub('release-', '')}
    else
      tags
    end
  end

  private

  def pip_versions(name)
    data = JSON.parse(open("https://pypi.python.org/pypi/#{name}/json").read)
    data['releases'].keys.sort_by{ |v| Gem::Version.new(v) }.reverse
  end
end
