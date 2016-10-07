#!/usr/bin/env ruby

root_dir      = Dir.pwd

require_relative 'pivnet-metadata-writer'
require_relative "#{root_dir}/buildpacks-ci/lib/git-client"

metadata_dir  = File.join(root_dir, 'pivnet-dotnet-core-metadata', 'pivnet-metadata')
buildpack_dir = File.join(root_dir, 'buildpack-master')

buildpack_files = ''

Dir.chdir('pivotal-buildpack-cached') do
  buildpack_files = Dir["dotnet-core_buildpack-cached-v*.zip"]
end

if buildpack_files.count != 1
  puts "Expected 1 cached buildpack file, found #{buildpack_files.count}:"
  puts buildpack_files
  exit 1
else
  cached_buildpack_filename = buildpack_files.first

  writer = PivnetMetadataWriter.new(metadata_dir, buildpack_dir, cached_buildpack_filename)
  writer.run!

  Dir.chdir(metadata_dir) do
    GitClient.add_file('dotnet-core.yml')
    GitClient.safe_commit("Create Pivnet release metadata for .NET buildpack v#{writer.get_version}")
  end

  system("rsync -a pivnet-dotnet-core-metadata/ pivnet-dotnet-core-metadata-artifacts")
end
