#!/usr/bin/env ruby
# encoding: utf-8
require 'open3'
require 'fileutils'

puts "Buildpack name: java\n"

_, status = Open3.capture2e('cf', 'api', ENV['CF_API'])
raise 'cf target failed' unless status.success?

_, status = Open3.capture2e('cf','auth', ENV['USERNAME'], ENV['PASSWORD'])
raise 'cf auth failed' unless status.success?

puts "Original Buildpacks\n==================="
system('cf', 'buildpacks')

filename = Dir.glob("pivnet-production/#{ENV['BUILDPACK_NAME']}-buildpack-offline*.zip").first

puts "\ncf update-buildpack #{ENV['BUILDPACK_NAME']}_buildpack -p #{filename}"
out, status = Open3.capture2e('cf', 'update-buildpack', "#{ENV['BUILDPACK_NAME']}_buildpack", '-p', "#{filename}")
raise "cf update-buildpack failed: #{out}" unless status.success?
