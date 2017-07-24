#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"

name = 'Summarize upstream changes'
date = (Time.now - (8 * 24 * 60 * 60)).strftime('%Y-%m-%d')
description = "**Summarize** changes in the Heroku buildpacks since last week (or the last time this story was completed)."
tasks = %w(Go Nodejs Python Ruby).map do |task|
  "#{task} - https://github.com/heroku/heroku-buildpack-#{task.downcase}/compare/master@%7B#{date}%7D...master"
end
tasks << "Tag story with all affected buildpacks"
labels = %w(maintenance)

tracker_client = TrackerClient.new(
  ENV.fetch('TRACKER_API_TOKEN'),
  ENV.fetch('TRACKER_PROJECT_ID'),
  ENV.fetch('TRACKER_REQUESTER_ID').to_i
)
tracker_client.post_to_tracker(name: name, description: description, tasks: tasks, point_value: 0, labels: labels)
