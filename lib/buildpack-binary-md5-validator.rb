# encoding: utf-8
require_relative 'git-client'
require 'yaml'
require 'tmpdir'
require 'digest/md5'

class BuildpackBinaryMD5Validator
  def self.run!(buildpack_dir)
    uri_to_md5_mapping = get_uri_md5_sha_values(buildpack_dir)
    show_mismatches(uri_to_md5_mapping)
  end

  # uri -> md5
  def self.get_uri_md5_sha_values(buildpack_dir)
    data = {}

    release_tag_shas = GitClient.git_tag_shas(buildpack_dir)
    release_tag_shas.each do |release_sha|
      begin
        manifest_contents = GitClient.get_file_contents_at_sha(buildpack_dir, release_sha, 'manifest.yml')
        manifest = YAML.load(manifest_contents)

        manifest["dependencies"].each do |dependency|
          next if data[dependency["uri"]]

          if dependency.key?( "md5")
            data[dependency["uri"]] = { "md5" => dependency["md5"], "sha" => release_sha }
          end
        end
      rescue Exception => e
        puts "failed to parse manifest at #{release_sha}: #{e}"
      end
    end
    data
  end

  def self.show_mismatches(uri_mapping)
    mismatches = []

    Dir.mktmpdir do |tmpdir_path|
      Dir.chdir(tmpdir_path) do
        puts "working in #{tmpdir_path}"

        uri_mapping.each do |uri, metadata_hash|
          desired_md5 = metadata_hash['md5']
          release_tag_sha = metadata_hash['sha']
          file = uri.gsub(/[^a-zA-Z0-9\.]/, "_")

          system "wget -q -c #{uri} -O #{file}"
          actual_md5 = Digest::MD5.file(file).to_s

          if desired_md5 == actual_md5
            print '.'
          else
            print 'F'
            mismatches << "#{uri}: actual #{actual_md5} != desired #{desired_md5}, release sha: #{release_tag_sha}"
          end
        end
      end
    end

    puts ""
    puts mismatches.join("\n")
  end
end
