#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'yaml'
require_relative 'dispatch'

class SemanticVersion
  attr_reader :major, :minor, :patch

  def initialize(original)
    @original = original
    m = @original.match(/^v?(\d+)\.(\d+)(\.(\d+))?(.+)?/)
    raise ArgumentError, "Not a semantic version: #{@original.inspect}" unless m

    @major = m[1].to_i
    @minor = m[2].to_i
    @patch = m[4] ? m[4].to_i : 0
    @metadata = m[5] || nil
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
             .split
             .compact
             .map { |bp| "#{bp}-buildpack" }

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

data = JSON.parse(File.read('source/data.json'))
name = data.dig('source', 'name')
version = data.dig('version', 'ref')

ENV['EXISTING_VERSION_LINES'].split.each do |line|
  semantic_version = SemanticVersion.new(version)
  filter = SemanticVersionFilter.new(line)
  if filter.match(semantic_version)
    puts "#{version} is already part of #{line}"
    exit 0
  end
end

puts 'Sending dispatch to create github issue...'
send_dispatch(name, version, data, ENV.fetch('GITHUB_TOKEN', nil))

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
