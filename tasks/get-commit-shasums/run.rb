#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/git-client"

latest_shasum_file = Dir["buildpack-artifacts/*.SHA256SUM.txt"].first
system("rsync -a buildpack-checksums/ sha-artifacts")
FileUtils.copy(latest_shasum_file, './sha-artifacts')

shasum_basename = File.basename(latest_shasum_file, ".SHA256SUM.txt")

Dir.chdir('sha-artifacts') do
  GitClient.add_everything
  GitClient.safe_commit("SHA256SUM for #{shasum_basename}")
end
