#!/usr/bin/env ruby

require 'yaml'
require_relative '../../lib/git-client'


class BuildpackBOSHReleaseUpdater
  def initialize(version, gcs_json_key, access_key_id, secret_access_key, assume_role_arn, language, release_name, release_tarball_dir)
    @version = version
    @gcs_json_key = gcs_json_key
    @access_key_id = access_key_id
    @secret_access_key = secret_access_key
    @assume_role_arn = assume_role_arn
    @language = language
    @release_name = release_name
    @release_tarball_dir = release_tarball_dir
  end

  def run!
    if @access_key_id
      write_private_yml_aws
    elsif @gcs_json_key
      write_private_yml_gcs
    else
      puts "Neither AWS nor GCP creds passed. exiting."
      exit 1
    end
    delete_old_blobs
    add_new_blobs
    create_release
    write_version
  end

  def write_private_yml_gcs
    puts "creating private.yml (GCS bucket)"
    private_yml = <<~YAML
                     ---
                     blobstore:
                       options:
                         credentials_source: static
                         json_key: #{@gcs_json_key}
                     YAML
    File.write('config/private.yml', private_yml)
  end

  def write_private_yml_aws
    puts "creating private.yml (AWS S3 bucket)"

    if @assume_role_arn && !@assume_role_arn.empty?
    private_yml = <<~YAML
                     ---
                     blobstore:
                       options:
                         access_key_id: #{@access_key_id}
                         secret_access_key: #{@secret_access_key}
                         assume_role_arn: #{@assume_role_arn}
                     YAML
    else
    private_yml = <<~YAML
                     ---
                     blobstore:
                       options:
                         access_key_id: #{@access_key_id}
                         secret_access_key: #{@secret_access_key}
                     YAML
    end

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
    system "bosh2 -n create-release --final --version #{@version} --name #{@release_name} --tarball #{File.join(@release_tarball_dir, 'release.tgz')} --force" or exit 1

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
