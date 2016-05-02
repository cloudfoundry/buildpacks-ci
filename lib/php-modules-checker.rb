#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"

class PHPModulesChecker
  def self.create_tracker_story
    tracker_client = TrackerClient.new(
      ENV['TRACKER_API_TOKEN'],
      ENV['TRACKER_PROJECT_ID'],
      ENV['TRACKER_REQUESTER_ID'].to_i
    )
    title = "Check and/or Update PHP Modules"
    description = <<-DESCRIPTION
Check that the PHP Module versions used in building PHP 5 and PHP 7 are up to date. If there are new, compatible versions, update them and build new PHP binaries.

Reference the PHP5 and PHP7 recipes and module versions used in cooking these recipes in [binary-builder](https://github.com/cloudfoundry/binary-builder)
    DESCRIPTION
    tasks = ["Check PHP 5 Modules", "Update PHP 5 Modules", "Check PHP 7 Modules", "Update PHP 7 Modules"]
    points = 1
    tracker_client.post_to_tracker title, description, tasks, points
  end
end
