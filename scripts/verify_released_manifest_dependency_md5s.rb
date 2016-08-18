#! /usr/bin/env ruby

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require_relative "#{buildpacks_ci_dir}/lib/buildpack-binary-md5-validator"

buildpack_dir = "/Users/pivotal/workspace/ruby-buildpack"
BuildpackBinaryMD5Validator.run!(buildpack_dir)
