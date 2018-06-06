#!/usr/bin/env ruby
# encoding: utf-8
require 'open3'
require 'fileutils'

puts "Buildpack name: #{ENV['BUILDPACK_NAME']}\n"

_, status = Open3.capture2e('cf', 'api', ENV['CF_API'])
raise 'cf target failed' unless status.success?

_, status = Open3.capture2e('cf','auth', ENV['USERNAME'], ENV['PASSWORD'])
raise 'cf auth failed' unless status.success?

puts "Original Buildpacks\n==================="
system('cf', 'buildpacks')

if ENV['BUILDPACK_NAME'] == 'java'
  orig_filename = Dir.glob("pivnet-production/#{ENV['BUILDPACK_NAME']}-buildpack-offline*.zip").first
  File.write('manifest.yml','stack: cflinuxfs2')
  system(<<~EOF)
          zip #{orig_filename} manifest.yml
          EOF
  filename = orig_filename.gsub(/-offline/,'-offline-cflinuxfs2') #TODO: Do not hard code stack
  FileUtils.mv(orig_filename, filename)
else
  orig_filename = Dir.glob("pivotal-buildpacks-cached/#{ENV['BUILDPACK_NAME']}*.zip").first
  filename = orig_filename.gsub(/\+\d+\.zip$/, '.zip')
  FileUtils.mv(orig_filename, filename)
end

if ENV['BUILDPACK_NAME'] != 'dotnet-core'
  puts "\ncf update-buildpack #{ENV['BUILDPACK_NAME']}_buildpack -p #{filename}"
  out, status = Open3.capture2e('cf', 'update-buildpack', "#{ENV['BUILDPACK_NAME']}_buildpack", '-p', "#{filename}")
else
  puts "\ncf update-buildpack dotnet_core_buildpack -p #{filename}"
  out, status = Open3.capture2e('cf', 'update-buildpack', 'dotnet_core_buildpack', '-p', "#{filename}")
end

raise "cf update-buildpack failed: #{out}" unless status.success?
