#!/usr/bin/env ruby

require 'yaml'
require_relative '../../lib/git-client'


class BuildpackBOSHReleaseUpdater
  def initialize(version, access_key_id, secret_access_key, language, release_name)
    @version = version
    @access_key_id = access_key_id
    @secret_access_key = secret_access_key
    @language = language
    @release_name = release_name
  end

  def run!
    write_private_yml if @access_key_id
    delete_old_blobs
    add_new_blobs
    create_release
    write_version
  end

  def write_private_yml
    puts "creating private.yml"

    private_yml = <<~YAML
                     ---
                     blobstore:
                       options:
                         access_key_id: #{@access_key_id}
                         secret_access_key: #{@secret_access_key}
                     YAML

    File.write('config/private.yml', private_yml)
  end

  def delete_old_blobs
    blobs = YAML.load_file('config/blobs.yml') || {}

    blobs.keys.each do |key|
      blobs.delete(key) if key.include?('buildpack')
    end

    File.write('config/blobs.yml', YAML.dump(blobs))
  end

  def add_new_blobs
    blob_name = "#{@language}-buildpack"
    Dir["../buildpack-zip*/#{@language}*.zip"].each do |buildpack_file|
      system "bosh2 -n add-blob #{buildpack_file} #{blob_name}/#{File.basename(buildpack_file.gsub(/\+.*\.zip/, '.zip'))}" or exit 1
    end

    system "bosh2 -n upload-blobs" or exit 1

    GitClient.add_file('config/blobs.yml')
    GitClient.safe_commit("Updating blobs for #{@release_name} at #{@version}")
  end

  def create_release
    system "bosh2 -n create-release --final --version #{@version} --name #{@release_name} --force" or exit 1

    GitClient.add_file("releases/**/*-#{@version}.yml")
    GitClient.add_file("releases/**/index.yml")
    GitClient.add_file(".final_builds/**/index.yml")
    GitClient.add_file(".final_builds/**/**/index.yml")
    GitClient.safe_commit("Final release for #{@release_name} at #{@version}")
  end

  def write_version
    File.write('../version/version', @version)
  end
end
