#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
binary_builds_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'built-out'))

require_relative "#{buildpacks_ci_dir}/lib/update-dependency-in-buildpack-job.rb"

update_job = UpdateDependencyInBuildpackJob.new(buildpacks_ci_dir, binary_builds_dir)
update_job.run!
