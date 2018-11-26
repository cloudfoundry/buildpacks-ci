#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'yaml'
require 'tracker_api'

BUILDPACKS = ENV['BUILDPACKS'].split(' ').compact

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

data = JSON.parse(open('source/data.json').read)
name = data.dig('source', 'name')
version = data.dig('version', 'ref')

tracker_client = TrackerApi::Client.new(token: ENV['TRACKER_API_TOKEN'])
buildpack_project = tracker_client.project(ENV['TRACKER_PROJECT_ID'])

if File.file?('all-monitored-deps/data.json')
  all_monitored_deps = JSON.parse(open('all-monitored-deps/data.json').read)
  data['packages'] = all_monitored_deps
end

story = buildpack_project.create_story(
  name: "Build and/or Include new releases: #{name} #{version}",
  description: "```\n#{data.to_yaml}\n```\n",
  estimate: 1,
  labels: (['deps', name] + BUILDPACKS).uniq,
  requested_by_id: ENV['TRACKER_REQUESTER_ID'].to_i,
  owner_ids: [ ENV['TRACKER_REQUESTER_ID'].to_i ]
)

puts "Created tracker story #{story.id}"

system('rsync -a builds/ builds-artifacts/')
raise('Could not copy builds to builds artifacts') unless $?.success?
Dir.chdir('builds-artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  version = data.dig('version', 'ref')
  FileUtils.mkdir_p("binary-builds-new/#{data.dig('source', 'name')}")
  File.write("binary-builds-new/#{data.dig('source', 'name')}/#{version}.json", { tracker_story_id: story.id }.to_json)

  GitClient.add_file("binary-builds-new/#{data.dig('source', 'name')}/#{version}.json")
  GitClient.safe_commit("Create Tracker Story #{data.dig('source', 'name')} - #{version}")
end
