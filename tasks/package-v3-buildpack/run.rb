#!/usr/bin/env ruby
require 'toml'
require 'fileutils'

def get_changes
  changes = File.read('buildpack/CHANGELOG')
  recent_changes = changes.split(/^v[0-9\.]+.*?=+$/m)[1]

  if recent_changes != nil
    recent_changes = recent_changes.strip
  else
    recent_changes = ""
  end
  "TODO"
end

language = ENV['LANGUAGE']
release_body_file = File.absolute_path(File.join('release-artifacts', 'body'))

next_version = Gem::Version.new(TOML.load_file('buildpack/buildpack.toml')['buildpack']['version'])
last_version = `git tag`.split("\n").map {|i| Gem::Version.new(i.strip().tr('v', ''))}.sort.last

if last_version && next_version <= last_version
  raise "#{next_version.to_s} does not come after the current release #{last_version.to_s}"
end

File.write('release-artifacts/name', "v#{next_version.to_s}")
File.write('release-artifacts/tag', "v#{next_version.to_s}")

File.write(release_body_file, "#{get_changes}\n")

target = File.join(Dir.pwd, "release-artifacts", "#{language}-cnb-#{next_version.to_s}")
Dir.chdir('buildpack') do
  `PACKAGE_DIR=#{target} ./scripts/package.sh -a -v #{next_version.to_s}` or raise 'failed to package cnb'
  File.write(release_body_file, `#{packager_path} -summary`, mode: 'a')
end
