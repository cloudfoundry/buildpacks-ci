#!/usr/bin/env ruby

require_relative '../../lib/buildpack-release-story-creator'

buildpack_name = ENV['BUILDPACK_NAME']
previous_buildpack_version = File.read('buildpack/VERSION')
tracker_project_id = ENV['TRACKER_PROJECT_ID']
tracker_requester_id = ENV['TRACKER_REQUESTER_ID'].to_i
tracker_api_token = ENV['TRACKER_API_TOKEN']

buildpack_release_story_creator = BuildpackReleaseStoryCreator.new(
    buildpack_name:             buildpack_name,
    previous_buildpack_version: previous_buildpack_version,
    tracker_project_id:         tracker_project_id,
    tracker_requester_id:       tracker_requester_id,
    tracker_api_token:          tracker_api_token
)

puts "Running BuildpackReleaseStoryCreator for #{buildpack_name}"

buildpack_release_story_creator.run!
