#!/usr/bin/env ruby

root_dir      = Dir.pwd

require_relative 'buildpack-pivnet-metadata-writer'
require_relative "#{root_dir}/buildpacks-ci/lib/git-client"

buildpack = ENV.fetch('BUILDPACK')
lts_product = ENV.fetch('LTS_PRODUCT')
metadata_dir  = File.join(root_dir, 'pivnet-buildpack-metadata', 'pivnet-metadata')
metadata_file  = lts_product == 'true' ? "#{buildpack}-lts.yml" : "#{buildpack}.yml"
buildpack_dir = File.join(root_dir, 'buildpack')
recent_changes_filename = File.join(root_dir, 'buildpack-artifacts', 'RECENT_CHANGES')
buildpack_files = Dir["pivotal-buildpacks-*/#{buildpack}_buildpack-cached*-v*.zip"]

writer = BuildpackPivnetMetadataWriter.new(buildpack, metadata_dir, buildpack_dir, buildpack_files, recent_changes_filename, lts_product)
writer.run!

Dir.chdir(metadata_dir) do
  GitClient.add_file(metadata_file)
  GitClient.safe_commit("Create Pivnet release metadata for #{buildpack.capitalize} buildpack v#{writer.get_version}")
end

system("rsync -a pivnet-buildpack-metadata/ pivnet-buildpack-metadata-artifacts")
