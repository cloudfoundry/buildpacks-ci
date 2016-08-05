#!/usr/bin/env ruby
# encoding: utf-8

task_root_dir = File.expand_path(File.join(File.dirname(__FILE__), '..','..'))
binary_builder_dir = File.join(task_root_dir, 'binary-builder')

require "#{task_root_dir}/buildpacks-ci/lib/concourse-binary-builder"

ConcourseBinaryBuilder.new(ENV['BINARY_NAME'], task_root_dir, binary_builder_dir, ENV['GIT_SSH_KEY']).run
