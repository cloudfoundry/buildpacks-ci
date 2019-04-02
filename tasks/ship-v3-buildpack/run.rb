#!/usr/bin/env ruby
require 'octokit'
require 'toml'
require 'fileutils'

Octokit.auto_paginate = true
Octokit.configure do |c|
  c.login    = ENV.fetch('GITHUB_USERNAME')
  c.password = ENV.fetch('GITHUB_PASSWORD')
  token = ENV.fetch("GIT_TOKEN","")
  c.access_token = token if token != ""
end
language = ENV['LANGUAGE']

last_version = Gem::Version.new("0.0.0")

releases = Octokit.releases("cloudfoundry/#{language}-cnb").map(&:name)
if releases.size > 0
  last_version = Gem::Version.new(releases.first.gsub('v',''))
end

next_version = Gem::Version.new(TOML.load_file('buildpack/buildpack.toml')['buildpack']['version'])

if next_version > last_version
  File.write('release-artifacts/name', "v#{next_version.to_s}")
  File.write('release-artifacts/tag', "v#{next_version.to_s}")
  changes = File.read('buildpack/CHANGELOG')
  recent_changes = changes.split(/^v[0-9\.]+.*?=+$/m)[1].strip
  File.write('release-artifacts/body', "#{recent_changes}\n")

  output = ""
  Dir.chdir('buildpack') do
    output = `scripts/package.sh`
  end

  packaged_buildpack = /^Buildpack packaged into: (.*)$/.match(output)[1]
  `tar cvzf release-artifacts/#{language}-cnb-#{next_version.to_s}.tgz -C #{packaged_buildpack} .`
else
  raise "#{next_version.to_s} does not come after the current release #{last_version.to_s}"
end
