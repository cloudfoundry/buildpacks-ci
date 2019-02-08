#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"

name = 'Upgrade LTS'
date = (Time.now - (8 * 24 * 60 * 60)).strftime('%Y-%m-%d')
description = <<~HEREDOC
    **Upgrade** out Toolsmiths LTS Environment.
    Our current enviroment is: #{ENV.fetch('ENV_URL')}

    ***Notes***:
    - This will be a new toolsmiths environment on GCP which you can create [here](https://environments.toolsmiths.cf-app.com/deploy).
    - We will need our gcp json key which will be in lastpass
    - We will need to save the credentials for the new environment in lastpass
    - We will need to point all buildpack LTS tests at this new environment using the new credentials
    - We should delete the old environment
    HEREDOC

labels = %w(maintenance)

tracker_client = TrackerClient.new(
  ENV.fetch('TRACKER_API_TOKEN'),
  ENV.fetch('TRACKER_PROJECT_ID'),
  ENV.fetch('TRACKER_REQUESTER_ID').to_i
)
tracker_client.post_to_tracker(name: name, description: description, tasks: [], point_value: 0, labels: labels)
