#!/usr/bin/env ruby
# encoding: utf-8
#

require 'yaml'
require 'date'
require_relative '../../lib/buildpack-deprecation-story-creator'

buildpack_name = ENV.fetch('BUILDPACK_NAME')
manifest = YAML.load_file(File.join('buildpack', 'manifest.yml'))
date = Date.today
tracker_project_id = ENV.fetch('TRACKER_PROJECT_ID')
tracker_requester_id = ENV.fetch('TRACKER_REQUESTER_ID').to_i
before_story_id = ENV.fetch('BEFORE_STORY_ID').to_i
tracker_api_token = ENV.fetch('TRACKER_API_TOKEN')

notifier = BuildpackDeprecationStoryCreator.new(
    buildpack_name: buildpack_name,
    manifest: manifest,
    date: date,
    tracker_project_id: tracker_project_id,
    tracker_requester_id: tracker_requester_id,
    tracker_api_token: tracker_api_token,
    before_story_id: before_story_id
)

notifier.run
