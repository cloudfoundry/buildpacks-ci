#! /usr/bin/env ruby

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/buildpack-binary-md5-verifier"

# uris that should not be checked because the binaries are already replaced and
# we have vetted these uris/agree that they're not a concern
whitelist_file = File.join(Dir.pwd, 'verification-whitelist', 'whitelist.yml')

all_md5s_correct = true
Dir["*-buildpack"].each do |buildpack|
  puts "Now validating MD5s for the #{buildpack}"
  buildpack_dir = File.join(Dir.pwd, buildpack)
  all_md5s_correct = false unless BuildpackBinaryMD5Verifier.run!(buildpack_dir, whitelist_file)
end

if all_md5s_correct
  puts "All MD5s in buildpack release manifests are correct."
else
  puts "There were MD5s in buildpack release manifests that did not match up with the actual artifacts."
  exit 1
end
