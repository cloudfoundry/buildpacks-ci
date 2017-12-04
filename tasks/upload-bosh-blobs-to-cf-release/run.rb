#!/usr/bin/env ruby
# encoding: utf-8

require_relative '../../lib/cf-release-common'
require_relative '../../lib/git-client'

$stdout.sync = true

require 'yaml'
require 'fileutils'
require 'digest/sha1'

def buildpack_destination_dir(buildpack)
  buildpack = 'java' if buildpack =~ /offline/
  "#{buildpack}-buildpack"
end

buildpack = ENV.fetch('BUILDPACK')
version = ''

blob_store_private_yml = {
  'blobstore' => {
    'options' => {
      'access_key_id' => ENV.fetch('ACCESS_KEY_ID'),
      'secret_access_key' => ENV.fetch('SECRET_ACCESS_KEY')
    }
  }
}.to_yaml

buildpack_bosh_dir = File.join(Dir.pwd, 'buildpack-bosh-release')
cf_release_buildpack_submodule_dir = File.join(Dir.pwd, 'cf-release-artifacts', 'src', "#{buildpack}-buildpack-release")

puts `rsync -a cf-release/ cf-release-artifacts`

Dir.chdir('cf-release-artifacts') do
  File.write('config/private.yml', blob_store_private_yml)

  buildpack_blob = Dir["../buildpack-github-release/*.zip"].first
  matches = /v([\d\.]+)\.zip/.match(buildpack_blob)
  version = matches[1] if matches.size > 1
  puts "Version for #{buildpack} is #{version}"

  destination_dir = buildpack_destination_dir(buildpack)
  system "rm -f blobs/#{destination_dir}"
  blobs = YAML.load(File.read('config/blobs.yml'))

  old_buildpack_key = find_buildpack_key blobs, buildpack

  next unless old_buildpack_key
  new_sha = Digest::SHA1.file(buildpack_blob).hexdigest

  next unless new_sha != blobs[old_buildpack_key]['sha']
  blobs.delete(old_buildpack_key)
  File.write('config/blobs.yml', YAML.dump(blobs))

  exit 1 unless system "bosh2 reset-release"
  exit 1 unless system "bosh2 add-blob #{buildpack_blob} #{destination_dir}/#{File.basename(buildpack_blob)}"

  exit 1 unless system "bosh2 -n upload-blobs"
  exit 1 unless system "/usr/bin/env bash ./scripts/setup-git-hooks"

  GitClient.update_submodule_to_latest(buildpack_bosh_dir, cf_release_buildpack_submodule_dir)
  GitClient.add_everything
  GitClient.safe_commit("Update #{buildpack}-buildpack to v#{version}")
end
