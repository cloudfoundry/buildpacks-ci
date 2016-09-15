#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"
require 'json'

name = 'Build and/or Include new releases: PHP Modules'
description = <<-DESCRIPTION
Check that the PHP Module versions used in building PHP 5 and PHP 7 are up to date. If there are new, compatible versions, update them and build new PHP binaries.

Reference the PHP5 and PHP7 recipes and module versions used in cooking these recipes in [binary-builder](https://github.com/cloudfoundry/binary-builder)
DESCRIPTION
tasks = ['Check each PHP module for updates', 'Rebuild PHP versions if any module updates', 'Update PHP Buildpack with new PHP versions']
labels = %w(maintenance)

exit if name.empty?
description += "\n\n" unless description.empty?
description += "URL | Latest Version\n"
description += "--- | ---\n"

Dir.glob('./*/input.json').each do |json_file|
  begin
    json = JSON.parse(File.read(json_file))
    description += "#{json['source']['url']} | #{json['version']['version'].strip.gsub(/\s+/, ' -- ')}\n"
  rescue
    description += "#{json_file} | ERROR\n"
  end
end
Dir.glob('./*/tag').each do |tag_file|
  begin
    tag = File.read(tag_file)
    version = File.read(tag_file.gsub(/tag$/,'version'))
    source = tag_file.gsub(/\/tag$/,'').gsub(/^\.\//,'')
    description += "#{source} | #{tag} -- #{version}\n"
  rescue
    description += "#{tag_file} | ERROR\n"
  end
end

puts name
puts ""
puts description

tracker_client = TrackerClient.new(
  ENV['TRACKER_API_TOKEN'],
  ENV['TRACKER_PROJECT_ID'],
  ENV['TRACKER_REQUESTER_ID'].to_i
)
tracker_client.post_to_tracker(name: name, description: description, tasks: tasks, labels: labels)
