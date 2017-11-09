#!/usr/bin/env ruby

require_relative './finalize-security-notice-stories'
require_relative '../../lib/tracker-client.rb'

new_stack_version = File.read('version/number').strip.gsub(/-rc.*/, '')
token = ENV.fetch('TRACKER_API_TOKEN')
project_id = ENV.fetch('TRACKER_PROJECT_ID')
requester_id = ENV.fetch('TRACKER_REQUESTER_ID')

tracker_client = TrackerClient.new(token, project_id, requester_id.to_i)

FinalizeSecurityNoticeStories.new(tracker_client, new_stack_version).run
