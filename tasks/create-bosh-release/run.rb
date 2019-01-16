#!/usr/bin/env ruby

require_relative 'buildpack-bosh-release-updater'


versions = Dir["buildpack-zip*/version"].map do |buildpack_version_file|
  File.read(buildpack_version_file).gsub(/[\+#].*$/, '').gsub('Java Buildpack ', '')
end.uniq

if versions.size != 1
  puts "versions do not match #{versions}"
  exit 1
end

version = versions.first
access_key_id = ENV.fetch('ACCESS_KEY_ID', false)
secret_access_key = ENV.fetch('SECRET_ACCESS_KEY', false)
language = ENV.fetch('LANGUAGE')
release_name = ENV.fetch('RELEASE_NAME')

Dir.chdir(ENV.fetch('RELEASE_DIR')) do
  release_tags = `git tag`.split("\n")

  if release_tags.include?(version)
    puts "BOSH release version #{version} already exists"
    puts "exiting"
    exit 1
  end

  updater = BuildpackBOSHReleaseUpdater.new(
    version,
    access_key_id,
    secret_access_key,
    language,
    release_name)

  updater.run!
end

system "rsync -a release/ release-artifacts" or exit 1
