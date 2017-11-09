#! /usr/bin/env ruby

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/buildpack-binary-checksum-verifier"

# uris that should not be checked because the binaries are already replaced and
# we have vetted these uris/agree that they're not a concern
whitelist_file = File.join(Dir.pwd, 'verification-whitelist', 'binary-verification-whitelist' , 'whitelist.yml')

all_checksums_correct = true
Dir["*-buildpack"].each do |buildpack|
  puts "Now validating checksums for the #{buildpack}"
  buildpack_dir = File.join(Dir.pwd, buildpack)
  all_checksums_correct = false unless BuildpackBinaryChecksumVerifier.run!(buildpack_dir, whitelist_file)
end

if all_checksums_correct
  puts "All checksums in buildpack release manifests are correct."
else
  puts "There were checksums in buildpack release manifests that did not match up with the actual artifacts."
  exit 1
end
