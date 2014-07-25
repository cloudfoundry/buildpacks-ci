#!/usr/bin/env ruby

require 'yaml'

buildpack_path = ARGV[0]

if ARGV.count != 1
  puts "#{$0} [path_to_buildpack_zip]"
  exit 1
end

language = ENV['BUILDPACK_LANGUAGE']
private_yml_url = ENV['PRIVATE_YML_URL']

unless private_yml_url
  puts 'URL to config/private.yml, required in ENV'
  exit 1
end

unless ENV['GITHUB_CREDENTIALS']
  puts 'Github credentials required in ENV, used by "hub" command'
  exit 1
end

ENV['GITHUB_USER'], ENV['GITHUB_PASSWORD'] = ENV['GITHUB_CREDENTIALS'].split(':')

buildpack_filename = File.basename(buildpack_path)

version = buildpack_filename.match( /-(v.*)\.zip/)[1]
puts version
unless version
  puts 'Could not detect version of buildpack'
  exit 1
end

# Assume Jenkins has checked out our cf-release fork
##git clone https://github.com/cf-buildpacks/cf-release.git

puts `git config remote.cloudfoundry.url`

if $?.exitstatus == 1
  puts `git remote add cloudfoundry https://github.com/cloudfoundry/cf-release.git`
end

puts 'Updating cf-release to get newest develop branch'
puts `git remote update`

branch_name = "#{language}-buildpack-#{version}"
puts "creating branch: #{branch_name} based on cloudfoundry/develop"

puts `git checkout -b '#{branch_name}' cloudfoundry/develop`

package_dir = "packages/buildpack_#{language}"
spec_file = "#{package_dir}/spec"
packaging_file = "#{package_dir}/packaging"
buildpack_blob = "#{language}-buildpack/#{buildpack_filename}"

puts 'Updating spec file'
spec = YAML.load(File.read spec_file)
spec['files'] = [
  buildpack_blob
]

File.write(spec_file, YAML.dump(spec))

puts 'Updating Packaging file'
File.write(packaging_file, <<-PACKAGING_FILE)
set -e -x

cp #{buildpack_blob} ${BOSH_INSTALL_TARGET}
PACKAGING_FILE

puts 'Downloading private.yml'
`curl '#{private_yml_url}' -o config/private.yml`

puts 'Removing old buildpack from blobs.yml'
`rm blobs/#{language}-buildpack/*`
blobs = YAML.load(File.read('config/blobs.yml'))

old_buildpack_key = blobs.keys.detect do |key|
  key =~ /^#{language}-buildpack\//
end

unless old_buildpack_key
  puts 'Did not find key matching buildpack in blobs.yml already'
  exit 1
end
blobs.delete(old_buildpack_key)
File.write('config/blobs.yml', YAML.dump(blobs))

puts 'bosh add blob'
puts `bosh add blob #{buildpack_path}`

new_blobs = `bosh blobs|grep '^new'`.chomp.split("\n")
puts new_blobs
unless new_blobs.size == 1
  puts 'incorrect number of changed blobs'
  exit 1
end

blob_name = new_blobs.first.split("\t")[1]
unless blob_name == buildpack_filename
  puts "Found #{blob_name}, expected #{buildpack_filename}"
  exit 1
end

puts 'bosh upload blobs'
puts `bosh --non-interactive upload blobs`


puts 'Commiting changes'
puts `git add config/blobs.yml #{spec_file} #{packaging_file}`
puts `git commit -m 'Upgrading #{language} buildpack to #{version}'`

puts 'Pushing changes to origin'
puts `git push origin HEAD`

puts 'Submitting pull-request'
title = "Upgrading #{language} buildpack to #{version}"
body = "Upgrading to latest stable version of #{language} buildpack\n --Buildpacks Team"

puts `hub pull-request -m '#{title}\n\n#{body}' -b cloudfoundry:develop < /dev/null`

