#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/state-of-bosh-lites"

state_object = StateOfBoshLites.new

robots_dir = File.join(buildpacks_ci_dir, '..', 'public-buildpacks-ci-robots')
state_object.get_states!(resource_pools_dir: robots_dir)

display_type = 'text'
state_object.display_state(display_type.downcase)
