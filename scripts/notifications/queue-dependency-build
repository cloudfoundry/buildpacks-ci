#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
new_releases_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'new-releases'))
binary_builds_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'binary-builds'))

require "#{buildpacks_ci_dir}/lib/dependency-build-enqueuer"

dependency = ENV['DEPENDENCY']

build_enqueuer = DependencyBuildEnqueuer.new(dependency, new_releases_dir, binary_builds_dir)

#currently just trigger build for the latest dependency version
puts "Queueing build for #{build_enqueuer.dependency} #{build_enqueuer.latest_version}..."
build_enqueuer.enqueue_build
