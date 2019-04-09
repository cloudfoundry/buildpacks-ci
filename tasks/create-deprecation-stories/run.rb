#!/usr/bin/env ruby
# encoding: utf-8
#

require 'yaml'
require 'date'
require_relative 'deprecation-notifier'

buildpack_name = ENV.fetch('BUILDPACK_NAME')
manifest = YAML.load_file(File.join('buildpack', 'manifest.yml'))
date = Date.today
tracker_project_id = ENV.fetch('TRACKER_PROJECT_ID')
tracker_requester_id = ENV.fetch('TRACKER_REQUESTER_ID').to_i
tracker_api_token = ENV.fetch('TRACKER_API_TOKEN')

notifier = DeprecationNotifier.new(
    buildpack_name: buildpack_name,
    manifest: manifest,
    date: date,
    tracker_project_id: tracker_project_id,
    tracker_requester_id: tracker_requester_id,
    tracker_api_token: tracker_api_token
)

notifier.run