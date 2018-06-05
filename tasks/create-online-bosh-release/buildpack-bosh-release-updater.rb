#!/usr/bin/env ruby

require 'yaml'
require_relative '../../lib/cf-release-common'
require_relative '../../lib/git-client'


class BuildpackBOSHReleaseUpdater
  def initialize(version, access_key_id, secret_access_key, languages, release_name)
    @version = version
    @access_key_id = access_key_id
    @secret_access_key = secret_access_key
    @languages = languages
    @release_name = release_name
  end

  def run!
    write_private_yml if @access_key_id
    delete_old_blob
    add_new_blobs
    create_release
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

  def delete_old_blob
    blobs = YAML.load_file('config/blobs.yml') || {}

    old_buildpack_key = find_buildpack_key blobs, @release_name.gsub('-buildpack', '')

    blobs.delete(old_buildpack_key)

    File.write('config/blobs.yml', YAML.dump(blobs))
  end

  def add_new_blobs
    @languages.each do |language|
      blob_name = "#{language}-buildpack"
      Dir["../blob/#{language}*.zip"].each do |buildpack|
        system "bosh2 -n add-blob #{buildpack} #{blob_name}/#{File.basename(buildpack)}" or exit 1
      end

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
end
