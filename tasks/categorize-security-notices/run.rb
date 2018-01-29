#!/usr/bin/env ruby

require_relative './categorize-security-notices.rb'
require_relative '../../lib/tracker-client.rb'
require_relative '../../lib/davos_client.rb'

Dir.chdir('cflinuxfs2-release') do
  Dir.mkdir('source')
  `tar -xzf source.tar.gz -C source`
end

tracker_api_token = ENV.fetch('TRACKER_API_TOKEN')
tracker_project_id = ENV.fetch('TRACKER_PROJECT_ID')
tracker_requester_id = ENV.fetch('TRACKER_REQUESTER_ID')
davos_token = ENV.fetch('DAVOS_TOKEN')

tracker_client = TrackerClient.new(tracker_api_token, tracker_project_id, tracker_requester_id.to_i)
receipt_path = Dir.glob(File.join('cflinuxfs2-release', 'source', 'cloudfoundry-cflinuxfs2-*', 'cflinuxfs2', 'cflinuxfs2_receipt')).first

davos_client = DavosClient.new(davos_token)

CategorizeSecurityNotices.new(tracker_client,
  'davos-cve-stories/data',
  receipt_path,
  davos_client
).run
