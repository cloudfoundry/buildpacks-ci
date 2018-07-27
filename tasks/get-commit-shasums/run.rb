#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/git-client"

latest_shasum_files = Dir["buildpack-artifacts/*.SHA256SUM.txt"]
system("rsync -a buildpack-checksums/ sha-artifacts")

latest_shasum_files.each do |latest_shasum_file|
  FileUtils.copy(latest_shasum_file, './sha-artifacts')
end

shasum_basenames = latest_shasum_files.map do |latest_shasum_file|
  File.basename(latest_shasum_file, ".SHA256SUM.txt")
end

Dir.chdir('sha-artifacts') do
  GitClient.add_everything
  GitClient.safe_commit("SHA256SUM for #{shasum_basenames.join(' ')}")
end
