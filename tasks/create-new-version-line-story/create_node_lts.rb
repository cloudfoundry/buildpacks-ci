#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'yaml'
require_relative './dispatch.rb'

BUILDPACKS = ENV['BUILDPACKS']
                 .split(' ')
                 .compact
                 .map {|bp| "#{bp}-buildpack" }

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

data = JSON.parse(open('source/data.json').read)
name = data.dig('source', 'name')
version = data.dig('version', 'ref')

if File.file?('all-monitored-deps/data.json')
  all_monitored_deps = JSON.parse(open('all-monitored-deps/data.json').read)
  data['packages'] = all_monitored_deps
end

puts "Sending dispatch to create github issue..."
send_dispatch(name, version, data, ENV['GITHUB_TOKEN'])
