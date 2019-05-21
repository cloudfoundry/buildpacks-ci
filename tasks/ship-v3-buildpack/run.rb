#!/usr/bin/env ruby
require 'octokit'
require 'toml'
require 'fileutils'

language = ENV['LANGUAGE']
packager_path = File.absolute_path(File.join('buildpack', '.bin', 'packager'))
release_body_file = File.absolute_path(File.join('release-artifacts', 'body'))

next_version = Gem::Version.new(TOML.load_file('buildpack/buildpack.toml')['buildpack']['version'])
last_version = `git tag`.split("\n").map {|i| Gem::Version.new(i.strip().tr('v', ''))}.sort.last

if last_version && next_version <= last_version
  raise "#{next_version.to_s} does not come after the current release #{last_version.to_s}"
end

Dir.chdir('packager/packager') do
  `go build -o #{packager_path}`
end

File.write('release-artifacts/name', "v#{next_version.to_s}")
File.write('release-artifacts/tag', "v#{next_version.to_s}")
changes = File.read('buildpack/CHANGELOG')
recent_changes = changes.split(/^v[0-9\.]+.*?=+$/m)[1]

if recent_changes != nil
  recent_changes = recent_changes.strip
else
  recent_changes = ""
end

File.write(release_body_file, "#{recent_changes}\n")

target = File.join(Dir.pwd, "release-artifacts", "#{language}-cnb-#{next_version.to_s}")
Dir.chdir('buildpack') do
  `#{packager_path} -archive -uncached #{target}`
  File.write(release_body_file, `#{packager_path} -summary`, mode: 'a')
end
