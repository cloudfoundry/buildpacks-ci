#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
new_releases_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'new-releases'))

require "#{buildpacks_ci_dir}/lib/new-releases-detector"

Dir.chdir("#{buildpacks_ci_dir}/scripts/notifications") do
  new_releases_detector = NewReleasesDetector.new(new_releases_dir)
  new_releases_detector.post_to_tracker
  new_releases_detector.post_to_slack


  unless new_releases_detector.changed_dependencies.empty?
    Dir.chdir(new_releases_dir) do
      raise 'command failed' unless system('git add -A')
      raise 'command failed' unless system("git commit -m 'Updates for latest tags'")
    end
  end
end
