#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"

name = 'Summarize upstream changes'
description = <<~DESCRIPTION
                **Summarize** changes in the Heroku buildpacks since last week (or the last time this story was completed).

                Easy way to check for changes: Ex. https://github.com/heroku/heroku-buildpack-ruby/compare/master@%7B7day%7D...master
              DESCRIPTION
tasks = %w(Go Nodejs Python Ruby)
tasks << "Tag story with all affected buildpacks"
labels = %w(maintenance)

tracker_client = TrackerClient.new(
  ENV.fetch('TRACKER_API_TOKEN'),
  ENV.fetch('TRACKER_PROJECT_ID'),
  ENV.fetch('TRACKER_REQUESTER_ID').to_i
)
tracker_client.post_to_tracker(name: name, description: description, tasks: tasks, point_value: 1, labels: labels)
