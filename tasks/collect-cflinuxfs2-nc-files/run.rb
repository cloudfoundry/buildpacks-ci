#!/usr/bin/env ruby

require 'fileutils'

bosh_release = Dir['bosh-release-s3/*.tgz'].first

puts "Moving cflinuxfs2-nc BOSH release (#{bosh_release}) to files-to-upload/"
FileUtils.mv bosh_release, 'files-to-upload/'

puts 'Moving README to files-to-upload'
FileUtils.mv 'cflinuxfs2-rootfs-release/README.md', 'files-to-upload/'

