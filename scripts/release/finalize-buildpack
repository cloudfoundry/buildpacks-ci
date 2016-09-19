#!/usr/bin/env ruby
# encoding: utf-8
require 'digest'
require 'fileutils'

artifact_path = File.join(Dir.pwd, 'buildpack-artifacts')

tag = "v#{File.read('buildpack/VERSION')}"
File.write(File.join(artifact_path, 'tag'), tag)

Dir.chdir('buildpack') do
  num_cores = `nproc`
  system("BUNDLE_GEMFILE=cf.Gemfile bundle install --jobs=#{num_cores}")

  changes       = File.read('CHANGELOG')
  recent_change = changes.split(/^v[0-9\.]+.*?=+$/m)[1].strip

  File.write(File.join(artifact_path, 'RECENT_CHANGES'), [
    recent_change,
    "Packaged binaries:\n",
    `BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --list`,
    "Default binary versions:\n",
    `BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-packager --defaults`
  ].join("\n"))
end

Dir.chdir('pivotal-buildpacks-cached') do
  Dir.glob('*.zip').map do |filename|
    filename.match(/(.*)_buildpack-cached-v(.*)\+.*.zip/) do |match|
      _, language, version = match.to_a
      new_filename = "#{language}_buildpack-cached-v#{version}.zip"
      new_path     = File.join(artifact_path, new_filename)

      FileUtils.mv(filename, new_path)

      shasum = Digest::SHA256.file(new_path).hexdigest

      # append SHA to RELEASE NOTES
      File.write(File.join(artifact_path, 'RECENT_CHANGES'), "  * SHA256: #{shasum}", mode: 'a')
      File.write("#{new_path}.SHA256SUM.txt", "#{shasum}  #{new_filename}")
    end
  end
end
