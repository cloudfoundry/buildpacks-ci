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
  recent_changes = changes.split(/^v[0-9\.]+.*?=+$/m)[1]

  if recent_changes != nil 
    recent_changes = recent_changes.strip
  else 
    recent_changes = ""
  end
  
  File.write('release-artifacts/body', "#{recent_changes}\n")

  target = File.join(Dir.pwd, "release-artifacts", "#{language}-cnb-#{next_version.to_s}")
  Dir.chdir('buildpack') do
    `scripts/install_tools.sh`
    `.bin/packager -archive -uncached #{target}`
  end

else
  raise "#{next_version.to_s} does not come after the current release #{last_version.to_s}"
end
