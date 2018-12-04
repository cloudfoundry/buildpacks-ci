#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'
require 'open4'
require 'yaml'

version = "0.#{Time.now.to_i}"

replacements = []
Dir.glob('*-bosh-release').each do |bosh_release_dir|
  release_name = bosh_release_dir.match(/.*-buildpack/)[0]

  ## Bump blobs in bosh release
  Dir.chdir(bosh_release_dir) do
      ## Clean out existing blobs
    system(%(rm -rf blobs) || raise("can't remove blobs"))
    if File.exist?('config/blobs.yml')
      File.open('config/blobs.yml', 'w') { |file| file.write("---\n{}") }
    end

    pid, stdin, stdout, stderr = Open4.popen4 "bosh2 blobs | grep -- '-buildpack/.*buildpack' | awk '{print $1}'"
    stdin.close
    _, status = Process.waitpid2 pid
    status || raise("cannot list-blobs for #{release_name}-bosh-release:\n\n#{stdout}\n\n#{stderr}")
    stdout.each_line do |line|
      system(%(bosh2 remove-blob #{line}))
    end

    ## Add new blobs for new buildpacks
    Dir.glob("../#{release_name}*/*.zip") do |blob|
      system(%(bosh2 -n add-blob #{blob} #{release_name}/#{File.basename(blob)})) || raise("cannot add blob #{blob} to #{release_name}")
    end

    # Create release and copy to built-buildpacks-artifacts
    system(%(bosh2 create-release --force --tarball dev_releases/#{release_name}/#{release_name}-#{version}.tgz --name #{release_name} --version #{version})) || raise("cannot create #{release_name} #{version}")
    system(%(cp dev_releases/*/*.tgz ../built-buildpacks-artifacts/))
  end

  release_replacement = {
    "path" => "/releases/name=#{release_name}",
    "type" => "replace",
    "value" => {
      "name" => release_name,
      "version" => version
    }
  }
  replacements << release_replacement
end

File.open("bump-buildpacks-opsfile/opsfile.yml", 'w') {|f| f.write replacements.to_yaml }
