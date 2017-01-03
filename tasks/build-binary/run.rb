#!/usr/bin/env ruby
# encoding: utf-8

task_root_dir = File.expand_path(File.join(File.dirname(__FILE__), '..','..', '..'))

require "#{task_root_dir}/buildpacks-ci/lib/concourse-binary-builder"

ConcourseBinaryBuilder.new(ENV.fetch('DEPENDENCY'), task_root_dir, ENV.fetch('GIT_SSH_KEY'), ENV.fetch('BINARY_BUILDER_PLATFORM'), ENV.fetch('BINARY_BUILDER_OS_NAME')).run
