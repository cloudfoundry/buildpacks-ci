#!/usr/bin/env ruby
# encoding: utf-8

require_relative '../../lib/state-of-bosh-lites.rb'

deployment_id = ENV['DEPLOYMENT_NAME']
resource_pools_dir = File.join(Dir.pwd, 'resource-pools')

state_object = StateOfBoshLites.new
state_object.get_states!(resource_pools_dir: resource_pools_dir)

bosh_lite_name = deployment_id.split('.').first
if state_object.bosh_lite_in_pool?(deployment_id)
  puts "=========================================================================="
  puts "WARNING:"
  puts "You should trigger the #{bosh_lite_name} pipeline from the very beginning."
  puts "You should not be trying to re-run intermediate deploy/setup steps on an already functional BOSH Lite with CF and Diego successfully deployed to it."
  exit 1
else
  puts "#{bosh_lite_name} is not in the resource pool."
  puts "Job proceeding."
end
