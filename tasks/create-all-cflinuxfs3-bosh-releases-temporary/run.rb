#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'
require 'open4'
require 'yaml'

version = "0.#{Time.now.to_i}"

replacements = []
Dir.glob('*-buildpack-bosh-release').each do |bosh_release|
  release_name = bosh_release.gsub('-bosh-release', '')

  Dir.chdir("#{release_name}-bosh-release") do
    # Create release and copy to built-buildpacks-artifacts
    system(%(bosh create-release --force --tarball dev_releases/#{release_name}/#{release_name}-#{version}.tgz --name #{release_name} --version #{version})) || raise("cannot create #{release_name} #{version}")
    system(%(cp dev_releases/*/*.tgz ../built-buildpacks-artifacts/))
  end

  release_replacement = {
    "path" => "/releases/name=#{release_name}",
    "type" => "replace",
    "value" => {
      "name" => release_name,
      "version" => version
    }
  }
  replacements << release_replacement
end

File.open("buildpacks-opsfile/opsfile.yml", 'w') {|f| f.write replacements.to_yaml }
