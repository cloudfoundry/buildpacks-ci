#!/usr/bin/env ruby
# encoding: utf-8
require 'fileutils'

gem_name = ENV['GEM_NAME']

artifact_path = File.join(Dir.pwd, "gem-artifacts")

current_version = Dir.chdir('gem') do
  current_version = `bump current | egrep -o '[0-9\.]+'`
  tag = "v#{current_version}"
  File.write(File.join(artifact_path, 'tag'), tag)
  current_version.strip
end

compressed_file_target = "#{artifact_path}/#{gem_name}-v#{current_version}"
`zip -r #{compressed_file_target}.zip gem`
`tar -cvzf #{compressed_file_target}.tar.gz gem`
