#!/usr/bin/env ruby
require 'json'
require 'tracker_api'

data = JSON.parse(open('source/data.json').read)
build = JSON.parse(open("builds/binary-builds-new/#{data.dig('source', 'name')}/#{data.dig('version', 'ref')}.json").read)
tracker_story_id = build.dig('tracker_story_id') or raise 'tracker_story_id not found'

tracker_client = TrackerApi::Client.new(token: ENV['TRACKER_API_TOKEN'])
project = tracker_client.project(ENV['TRACKER_PROJECT_ID'])
story = project.story(tracker_story_id)
story.current_state = 'accepted'
story.save
