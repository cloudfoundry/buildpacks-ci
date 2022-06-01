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
    m = @original.match /^v?(\d+)\.(\d+)(\.(\d+))?(.+)?/
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

# NOTE: Keep in sync with 'dockerfiles/depwatcher/src/depwatcher/semantic_version.cr'!
class SemanticVersionFilter
  def initialize(filter_string)
    @filter_string = filter_string
  end

  def match(semver)
    other_string = "#{semver.major}.#{semver.minor}.#{semver.patch}"
    first_x_idx = @filter_string.index('X')
    if first_x_idx.nil?
      other_string == @filter_string
    else
      prefix = @filter_string[0, first_x_idx]
      other_string.start_with?(prefix) && @filter_string.size <= other_string.size
    end
  end
end

BUILDPACKS = ENV['BUILDPACKS']
                 .split(' ')
                 .compact
                 .map {|bp|
                   if bp.include? "-cnb"
                     bp
                   else
                     "#{bp}-buildpack"
                   end
                 }

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
  name: "Add new version line in dependency-builds: #{name} #{version}",
  description: "```\n#{data.to_yaml}\n```\n\nPlease edit the dependency-builds pipeline to add the new version line to the relevant dependency/buildpack.\n\nFor nginx/nginx-static: Also remove older mainline/stable version.\nE.g. If you are adding nginx 1.22, you will remove 1.20. If you are adding 1.23, you will remove 1.21",
  estimate: 1,
  labels: (['deps', name] + BUILDPACKS).uniq,
  requested_by_id: ENV['TRACKER_REQUESTER_ID'].to_i,
  owner_ids: [ENV['TRACKER_REQUESTER_ID'].to_i],
  before_id: ENV['TRACKER_BEFORE_ID'].to_i
)

puts "Created tracker story #{story.id}"
# Notes on depen version line additions:
# General stucture of dependencies is `dep.buildpacks.[].lines[].`
# eg.
# ```
# php:
#     buildpacks:
#       php:
#         lines:
# ```
# php:
# - Deprecations occur 3 years after the date the dep is released

