#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'
require 'yaml'

version = "0.#{Time.now.to_i}"

replacements = []
Dir.glob("*-buildpack-github-release").each do |github_release|
  release_name = github_release.gsub("-github-release", "")

  release_replacement = {
    "path" => "/releases/name=#{release_name}",
    "type" => "replace",
    "value" => {
      "name" => release_name,
      "version" => version
    }
  }
  Dir.chdir("#{release_name}-bosh-release") do
    system(%(bosh2 --parallel 10 sync-blobs && bosh2 create-release --force --tarball dev_releases/#{release_name}/#{release_name}-#{version}.tgz --name #{release_name} --version #{version})) || raise("cannot create #{release_name} #{version}")
    system(%(cp dev_releases/*/*.tgz ../built-buildpacks-artifacts/))
  end

  replacements << release_replacement
end

replacements << {
    "path" => "/releases/name=cflinuxfs2",
    "type" => "replace",
    "value" => {
      "name" => "cflinuxfs2",
      "version" => File.read("cflinuxfs2-bosh-release/version").strip,
      "sha1" => File.read("cflinuxfs2-bosh-release/sha1").strip,
      "url" => File.read("cflinuxfs2-bosh-release/url").strip
    }
}

File.open("bump-buildpacks-opsfile/opsfile.yml", 'w') {|f| f.write replacements.to_yaml }

