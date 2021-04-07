#!/usr/bin/env ruby
require 'octokit'
require_relative '../../lib/release-github-issue-generator'

buildpack_name = ENV.fetch('BUILDPACK_NAME')
previous_buildpack_version = `git -C buildpack-develop tag`.split("\n").map{ |i| i.strip.delete('v') }
  .select { |i| i =~ /\d+\.\d+\.\d+/ }.map { |i| Gem::Version.new(i) }.sort.last.to_s

old_manifest = `git -C buildpack-develop show v#{previous_buildpack_version}:manifest.yml`
new_manifest = File.read('buildpack-develop/manifest.yml')

client = Octokit::Client.new :access_token => ENV.fetch('GITHUB_ACCESS_TOKEN')

puts "Running ReleaseGithubIssueGenerator for #{buildpack_name}"

ReleaseGithubIssueGenerator.new(client).run(buildpack_name, previous_buildpack_version, old_manifest, new_manifest)
