#!/usr/bin/env ruby

require_relative '../../lib/buildpack-release-story-creator'

buildpack_name = ENV.fetch('BUILDPACK_NAME')
previous_buildpack_version = `git -C buildpack tag`.split("\n").map{ |i| i.strip.delete('v') }
  .select { |i| i =~ /\d+\.\d+\.\d+/ }.map { |i| Gem::Version.new(i) }.sort.last.to_s
tracker_project_id = ENV.fetch('TRACKER_PROJECT_ID')
releng_tracker_project_id = ENV.fetch('RELENG_TRACKER_PROJECT_ID')
tracker_requester_id = ENV.fetch('TRACKER_REQUESTER_ID').to_i
tracker_api_token = ENV.fetch('TRACKER_API_TOKEN')
old_manifest = `git -C buildpack show v#{previous_buildpack_version}:manifest.yml`
new_manifest = File.read('buildpack/manifest.yml')

buildpack_release_story_creator = BuildpackReleaseStoryCreator.new(
  buildpack_name:             buildpack_name,
  previous_buildpack_version: previous_buildpack_version,
  tracker_project_id:         tracker_project_id,
  releng_tracker_project_id:  releng_tracker_project_id,
  tracker_requester_id:       tracker_requester_id,
  tracker_api_token:          tracker_api_token,
  old_manifest:               old_manifest,
  new_manifest:               new_manifest
)

puts "Running BuildpackReleaseStoryCreator for #{buildpack_name}"

buildpack_release_story_creator.run!
