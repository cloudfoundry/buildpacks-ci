#!/usr/bin/env ruby
# encoding: utf-8
require 'fileutils'

latest_shasum_file = Dir["buildpack-artifacts/*.SHA256SUM.txt"].first
system("rsync -a buildpack-checksums/ sha-artifacts")
FileUtils.copy(latest_shasum_file, './sha-artifacts')

Dir.chdir('sha-artifacts') do
  GitClient.add_everything
  GitClient.safe_commit("SHA256SUM for #{shasum_basename}")
end
