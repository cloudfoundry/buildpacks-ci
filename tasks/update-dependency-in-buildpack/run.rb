#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
binary_built_out_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'built-out'))

require_relative "update-dependency-in-buildpack-job"

update_job = UpdateDependencyInBuildpackJob.new(buildpacks_ci_dir, binary_built_out_dir)
update_job.run!
