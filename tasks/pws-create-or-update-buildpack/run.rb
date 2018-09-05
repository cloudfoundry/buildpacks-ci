#!/usr/bin/env ruby
# encoding: utf-8
require 'open3'
require 'fileutils'
require 'json'

puts "Buildpack name: #{ENV['BUILDPACK_NAME']}\n"

_, status = Open3.capture2e('cf', 'api', ENV['CF_API'])
raise 'cf target failed' unless status.success?

_, status = Open3.capture2e('cf','auth', ENV['USERNAME'], ENV['PASSWORD'])
raise 'cf auth failed' unless status.success?

puts "Original Buildpacks\n==================="
system('cf', 'buildpacks')

stacks = ENV['STACKS'].split(' ')
stacks.each do |stack|
  if ENV['BUILDPACK_NAME'] == 'java'
    orig_filename = Dir.glob("pivnet-production/#{ENV['BUILDPACK_NAME']}-buildpack-offline*.zip").first
    File.write('manifest.yml',"stack: #{stack}")
    system(<<~EOF)
            zip #{orig_filename} manifest.yml
            EOF
    filename = orig_filename.gsub(/-offline/,"-offline-#{stack}")
    FileUtils.cp(orig_filename, filename)
  else
    orig_filename = Dir.glob("pivotal-buildpack-cached-#{stack}/#{ENV['BUILDPACK_NAME']}*.zip").first
    filename = orig_filename.gsub(/\+\d+\.zip$/, '.zip')
    FileUtils.mv(orig_filename, filename)
  end

  stack = '' if stack == 'any'
  buildpack_name = ENV['BUILDPACK_NAME'] != 'dotnet-core' ? ENV['BUILDPACK_NAME'] + '_buildpack' : 'dotnet_core_buildpack'

  if buildpack_exists(buildpack_name, stack)
    puts "\n#{buildpack_name} already exists with stack #{stack}; updating buildpack."
    puts "\ncf update-buildpack #{buildpack_name} -p #{filename} -s #{stack}"
    out, status = Open3.capture2e('cf', 'update-buildpack', "#{buildpack_name}", '-p', "#{filename}", '-s', "#{stack}")
    raise "cf update-buildpack failed: #{out}" unless status.success?
  else
    puts "\n#{buildpack_name} with #{stack} does not exist; creating buildpack."
    puts "\ncf create-buildpack #{buildpack_name} #{filename} 0"
    out, status = Open3.capture2e('cf', 'create-buildpack', "#{buildpack_name}", "#{filename}", '0')
    raise "cf create-buildpack failed: #{out}" unless status.success?
  end
end

def buildpack_exists(name, stack)
  out, status = Open3.capture2e('cf', 'curl', "/v2/buildpacks")
  raise "curling cf v2 buildpack failed: #{out}" unless status.success?
  response = JSON.parse(out)
  response["resources"].each do |resource|
    if resource["entity"]["name"] == name && resource["entity"]["stack"] == stack_mapping(stack)
      return true
    end
  end
  false
end

def stack_mapping(stack)
  return stack == '' ? nil : stack
end
