#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"

name = "Monday-Funday *#{ENV.fetch("STACK")}* release"
description = "This is a reminder that a #{ENV.fetch("STACK")} release was automatically started, please monitor it, and deliver story when done."
labels = %w(pm-only maintenance)

tracker_client = TrackerClient.new(
  ENV.fetch('TRACKER_API_TOKEN'),
  ENV.fetch('TRACKER_PROJECT_ID'),
  ENV.fetch('TRACKER_REQUESTER_ID').to_i
)
tracker_client.post_to_tracker(name: name, description: description, point_value: 1, labels: labels)
