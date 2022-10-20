#!/usr/bin/env ruby
require 'json'

data = JSON.parse(open('source/data.json').read)
source_name = data.dig('source', 'name')
resource_version = data.dig('version', 'ref')

story_id = JSON.parse(open("builds/binary-builds-new/#{source_name}/#{resource_version}.json").read)['tracker_story_id']

Dir.mkdir('tracker-story-id') unless Dir.exist?('builds')
File.write('tracker-story-id/id', story_id)
