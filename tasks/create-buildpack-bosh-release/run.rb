#!/usr/bin/env ruby

require_relative 'buildpack-bosh-release-updater'

version = File.read('version/number').strip
access_key_id = ENV.fetch('ACCESS_KEY_ID', false)
secret_access_key = ENV.fetch('SECRET_ACCESS_KEY', false)
blob_name = ENV.fetch('BLOB_NAME')
blob_glob = ENV.fetch('BLOB_GLOB')
release_name = ENV.fetch('RELEASE_NAME')


Dir.chdir(ENV.fetch('RELEASE_DIR')) do
  updater = BuildpackBOSHReleaseUpdater.new(
    version,
    access_key_id,
    secret_access_key,
    blob_name,
    blob_glob,
    release_name)

  updater.run!
end

system "rsync -a release/ release-artifacts" or exit 1
