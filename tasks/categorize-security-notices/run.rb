#!/usr/bin/env ruby

require_relative './categorize-security-notices.rb'
require_relative '../../lib/tracker-client.rb'

tracker_api_token = ENV.fetch('TRACKER_API_TOKEN')
tracker_project_id = ENV.fetch('TRACKER_PROJECT_ID')
tracker_requester_id = ENV.fetch('TRACKER_REQUESTER_ID')
stack = ENV.fetch('STACK')

Dir.chdir("#{stack}-release") do
  Dir.mkdir('source')
  `tar -xzf source.tar.gz -C source`
end

tracker_client = TrackerClient.new(
  tracker_api_token,
  tracker_project_id,
  tracker_requester_id.to_i
)

receipt_file_glob = File.join("cloudfoundry-#{stack}-*", "receipt.#{stack}.x86_64")

receipt_path = Dir.glob(File.join(
  "#{stack}-release",
  'source',
  receipt_file_glob,
)).first

CategorizeSecurityNotices.new(
  tracker_client,
  'davos-cve-stories/data',
  receipt_path,
  stack
).run
