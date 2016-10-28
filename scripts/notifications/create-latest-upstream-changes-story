#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"

name = 'Pull latest changes from upstream'
description = <<~DESCRIPTION
                Check that there are no upstream changes that we are missing. Consult the documentation at http://docs.cloudfoundry.org/buildpacks/merging_upstream.html for more details.

                Easy way to check for changes: Ex. https://github.com/cloudfoundry/ruby-buildpack/compare/develop...heroku:master
              DESCRIPTION
tasks = %w(Go Nodejs Python Ruby)
tasks << "Tag story with all affected buildpacks"
labels = %w(maintenance)

tracker_client = TrackerClient.new(
  ENV['TRACKER_API_TOKEN'],
  ENV['TRACKER_PROJECT_ID'],
  ENV['TRACKER_REQUESTER_ID'].to_i
)
tracker_client.post_to_tracker(name: name, description: description, tasks: tasks, point_value: 1, labels: labels)
