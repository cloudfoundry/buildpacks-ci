#! /usr/bin/env ruby

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..'))
require_relative "#{buildpacks_ci_dir}/lib/buildpack-binary-md5-validator"

# uris that should not be checked because the binaries are already replaced and
# we have vetted these uris/agree that they're not a concern
whitelist_file = File.join(Dir.pwd, 'binary-verification-whitelist', 'whitelist.yml')

Dir["*-buildpack"].each do |buildpack|
  puts "Now validating md5s for the #{buildpack}"
  buildpack_dir = File.join(Dir.pwd, buildpack)
  BuildpackBinaryMD5Validator.run!(buildpack_dir, whitelist_file)
end
