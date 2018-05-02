#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'yaml'
require 'tracker_api'

class SemanticVersion
  attr_reader :major
  attr_reader :minor
  attr_reader :patch

  def initialize(original)
    @original = original
    m = @original.match /^(\d+)\.(\d+)(\.(\d+))?(.+)?/
    if m
      @major = m[1].to_i
      @minor = m[2].to_i
      @patch = m[4] ? m[4].to_i : 0
      @metadata = m[5] ? m[5] : nil
    else
      raise ArgumentError.new("Not a semantic version: #{@original.inspect}")
    end
  end

end

class SemanticVersionFilter
  def initialize(original)
    @original = original
    m = @original.match /^(\d+)\.(\d+|X)\.(\d+|X)$/
    if m
      @major = m[1].to_i
      @minor = m[2] == 'X' ? nil : m[2].to_i
      @patch = m[3] == 'X' ? nil : m[3].to_i
    else
      raise ArgumentError.new("Not a semantic version filter: #{@original.inspect}")
    end
  end

  def match(other)
    (@major == other.major) &&
    (@minor == nil || @minor == other.minor) &&
    (@patch == nil || @patch == other.patch)
  end
end


BUILDPACKS = ENV['BUILDPACKS'].split(' ').compact

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

data = JSON.parse(open('source/data.json').read)
name = data.dig('source', 'name')
version = data.dig('version', 'ref')

ENV['EXISTING_VERSION_LINES'].split(' ').each do |line|
  semantic_version = SemanticVersion.new(version)
  filter = SemanticVersionFilter.new(line)
  if filter.match(semantic_version)
    puts "#{version} is already part of #{line}"
    exit 0
  end
end

tracker_client = TrackerApi::Client.new(token: ENV['TRACKER_API_TOKEN'])
buildpack_project = tracker_client.project(ENV['TRACKER_PROJECT_ID'])

story = buildpack_project.create_story(
  name: "Add new version line in binary-builder-new: #{name} #{version}",
  description: "```\n#{data.to_yaml}\n```\n\nPlease edit the binary-builder-new pipeline to add the new version line to the relevant dependency/buildpack.",
  estimate: 1,
  labels: (['deps', name] + BUILDPACKS).uniq,
  requested_by_id: ENV['TRACKER_REQUESTER_ID'].to_i,
  owner_ids: [ENV['TRACKER_REQUESTER_ID'].to_i]
)

puts "Created tracker story #{story.id}"
